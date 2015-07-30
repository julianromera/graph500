#include "../comp_opt.h"
#include "cuda_bfs.h"
#include "b40c/util/error_utils.cuh"
#include <thrust/sort.h>
#include <thrust/device_vector.h>
#include <cstdlib>
#include <algorithm>
#include <functional>

#if defined( __PMODE__)
    #include <parallel/algorithm>
#endif


CUDA_BFS::CUDA_BFS(MatrixT &_store, int &num_gpus, double _queue_sizing, int64_t _verbosity) :
        GlobalBFS<CUDA_BFS, vtxtyp, unsigned char, MatrixT>(_store),
        verbosity(_verbosity),
        queue_sizing(_queue_sizing),
        vmask(0)
#ifdef _DEBUG
  , checkQueue(0, _store.getLocRowLength(), 0, _store.getLocColLength())
#endif
{

    int cpro_verbosity;
    b40c::util::B40CPerror(cudaSetDeviceFlags(cudaDeviceMapHost),
                           "Enabling of the allocation of pinned host memory faild", __FILE__, __LINE__);

    if (num_gpus == 0) {
        b40c::util::B40CPerror(cudaGetDeviceCount(&num_gpus),
                               "Can't get number of devices!", __FILE__, __LINE__);
    }

    //expect symmetries
    if (store.getNumRowSl() != store.getNumColumnSl()) {
        fprintf(stderr, "Currently the partitioning has to be symetric.");
        exit(1);
    }
    predecessor = new vtxtyp[store.getLocColLength()];

    fq_tp_type = MPI_INT64_T;
    bm_type = MPI_UNSIGNED_CHAR;
    recv_fq_buff_length = static_cast<vtxtyp>
    (std::max(store.getLocRowLength(), store.getLocColLength()) * queue_sizing);
    //recv_fq_buff = new vtxtyp[recv_fq_buff_length];
    cudaHostAlloc(&recv_fq_buff, recv_fq_buff_length * sizeof(vtxtyp), cudaHostAllocDefault);
    //multipurpose buffer
    qb_length = 0;
    cudaHostAlloc(&queuebuff, recv_fq_buff_length * sizeof(vtxtyp), cudaHostAllocDefault);
    rb_length = 0;
    cudaHostAlloc(&redbuff, recv_fq_buff_length * sizeof(vtxtyp), cudaHostAllocDefault);

    csr_problem = new Csr;

#ifdef INSTRUMENTED
   bfsGPU = new EnactorMultiGpu<Csr, true>;
#else
    bfsGPU = new EnactorMultiGpu<Csr, false>;
#endif

    cpro_verbosity = 0;
    if (verbosity >= 24) {
        cpro_verbosity = 2;
    } else if (verbosity >= 8) {
        cpro_verbosity = 1;
    }
    b40c::util::B40CPerror(csr_problem->FromHostProblem(
            false,                  //bool          stream_from_host,
            store.getLocRowLength(),//SizeT 		nodes,
            store.getEdgeCount(),   //SizeT 		edges,
            store.getColumnIndex(), //VertexId 	    *h_column_indices,
            store.getRowPointer(),  //SizeT 		*h_row_offsets,
            num_gpus,               //int 		num_gpus,
            cpro_verbosity          //verbosity
    ), "FromHostProblem failed!", __FILE__, __LINE__);
    /*
    //Test if peer comunication is possible
    bool peerPossible = true;
    for (int gpu = 0; gpu < num_gpus; gpu++) {
        Csr::GraphSlice* gs = csr_problem->graph_slices[gpu];
        for (int other_gpu = (gpu + 1) % num_gpus;
             other_gpu != gpu;
             other_gpu = (other_gpu + 1) % num_gpus)
        {
            Csr::GraphSlice* gs_other = csr_problem->graph_slices[other_gpu];
            int canAccessPeer;
            // Set device
            b40c::util::B40CPerror(cudaDeviceCanAccessPeer(&canAccessPeer,gs->gpu,gs_other->gpu)
                                   ,"Can not activate peer access!" ,__FILE__, __LINE__);
            if( !canAccessPeer  ){
               peerPossible = false;
               break;
            }
        }
    }
    */
    // Enable symmetric peer access between gpus
    // from test_bfs.cu
    // if(peerPossible)
    Csr::GraphSlice *gs;
    Csr::GraphSlice *gs_other;
    for (int gpu = 0; gpu < num_gpus; ++gpu) {
        gs = csr_problem->graph_slices[gpu];
        for (int other_gpu = (gpu + 1) % num_gpus;
             other_gpu != gpu;
             other_gpu = (other_gpu + 1) % num_gpus) {
            gs_other = csr_problem->graph_slices[other_gpu];
            // Set device
            if (b40c::util::B40CPerror(cudaSetDevice(gs->gpu),
                            "MultiGpuBfsEnactor cudaSetDevice failed", __FILE__, __LINE__)) {
                exit(1);
            }
            cudaError_t error = cudaDeviceEnablePeerAccess(gs_other->gpu, 0);
            if ((error != cudaSuccess) && (error != cudaErrorPeerAccessAlreadyEnabled)) {
                b40c::util::B40CPerror(error, "MultiGpuBfsEnactor cudaDeviceEnablePeerAccess failed", __FILE__,
                                       __LINE__);
                int canAccessPeer;
                b40c::util::B40CPerror(cudaDeviceCanAccessPeer(&canAccessPeer, gs->gpu, gs_other->gpu),
                                       "Can not access device!", __FILE__, __LINE__);
                if (canAccessPeer) {
                    fprintf(stderr, "Can access peer %d from %d!\n", gs_other->gpu, gs->gpu);
                } else {
                    fprintf(stderr, "Can't access peer %d from %d!\n", gs_other->gpu, gs->gpu);
                }
            }
        }
    }
}

CUDA_BFS::~CUDA_BFS() {

    if (vmask != 0) {
        cudaFreeHost(vmask);
    }

    delete bfsGPU;
    delete csr_problem;
    cudaFreeHost(redbuff);
    cudaFreeHost(queuebuff);
    cudaFreeHost(recv_fq_buff);
    delete[] predecessor;
}


/*
 * Function for reduction of the current and incoming frontier queue
 * Supports now only one gpu, because the vertexranges are not continuous
 */
void CUDA_BFS::reduce_fq_out(vtxtyp globalstart, long size, vtxtyp *startaddr, int insize) {

#ifdef _DEBUG
    CheckQueue<vtxtyp>::ErrorCode errorCode;
    if((errorCode=checkQueue.checkCol(startaddr, insize))!= CheckQueue<vtxtyp>::ErrorCode::Valid){
        std::cerr << "(" <<store.getLocalRowID() << ":" <<store.getLocalColumnID() << ") ";
        switch(errorCode){
            case CheckQueue<vtxtyp>::ErrorCode::InvalidLength:
            std::cerr << "Recieved queue with invalid length";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::IdsOutOfRange:
            std::cerr << "Recieved queue with ids out of range";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::NotSorted:
            std::cerr << "Recieved not sorted queue";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::DuplicteIds:
            std::cerr << "Recieved queue with duplicate ids";
            break;
            default:
            std::cerr << "Recieved invalid queue";
        }
        std::cerr << " from source node." << std::endl;
    }
#endif

    typename MatrixT::vtxtyp *start_local;
    typename MatrixT::vtxtyp *end_local;
    typename MatrixT::vtxtyp *endofresult;

    // determine the local range for the reduction
    start_local = std::lower_bound(queuebuff, queuebuff + qb_length, globalstart,
                                   [](vtxtyp a, vtxtyp b) { return a < (b & Csr::ProblemType::VERTEX_ID_MASK); });
    end_local = std::upper_bound(start_local, queuebuff + qb_length, globalstart + size - 1,
                                 [](vtxtyp a, vtxtyp b) { return b > (a & Csr::ProblemType::VERTEX_ID_MASK); });
    //reduction
    endofresult = std::set_union(start_local, end_local, startaddr, startaddr + insize, redbuff);

#ifdef _DEBUG
    //CheckQueue<vtxtyp>::ErrorCode errorCode;
    if((errorCode=checkQueue.checkCol(redbuff, endofresult - redbuff))!= CheckQueue<vtxtyp>::ErrorCode::Valid){
        std::cerr << "(" <<store.getLocalRowID() << ":" <<store.getLocalColumnID() << ") ";
        switch(errorCode){
            case CheckQueue<vtxtyp>::ErrorCode::InvalidLength:
            std::cerr << "Try to send queue with invalid length to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::IdsOutOfRange:
            std::cerr << "Try to send queue with ids out of range to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::NotSorted:
            std::cerr << "Try to send not sorted queue to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::DuplicteIds:
            std::cerr << "Try to send queue with duplicate ids to the device." << std::endl;
            break;
            default:
            std::cerr << "Try to send invalid queue to the device." << std::endl;
        }
    }
#endif

    qb_length = endofresult - redbuff;
    std::swap(queuebuff, redbuff);
}

void CUDA_BFS::getOutgoingFQ(vtxtyp *&startaddr, int &outsize) {
    startaddr = queuebuff;
    outsize = qb_length;
}

/*
 * -set the Outgoing queue after the column reduction
 * -recompute the visited mask
 */
void CUDA_BFS::setModOutgoingFQ(vtxtyp *startaddr, int insize) {
    int numGpus;

    numGpus = csr_problem->num_gpus;

#ifdef _OPENMP
    #pragma omp parallel for
#endif

    for (int i = 0; i < numGpus; ++i) {
        Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        b40c::util::B40CPerror(cudaStreamSynchronize(gs->stream),
                               "Can't synchronize Stream.", __FILE__, __LINE__);
    }

    if (startaddr != 0) {
        std::swap(recv_fq_buff, queuebuff);
        qb_length = insize;
    }
    //update visited
    for (int i = 0; i < qb_length; ++i) {
        typename Csr::ProblemType::VertexId vtxID = queuebuff[i] & Csr::ProblemType::VERTEX_ID_MASK;
        vmask[vtxID >> 3] |= 1 << (vtxID & 0x7);
    }

    int visited_mask_bytes;
    for (int i = 0; i < numGpus; ++i) {
        typename Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        visited_mask_bytes = ((csr_problem->nodes * sizeof(typename Csr::VisitedMask)) + 8 - 1) / 8;
        b40c::util::B40CPerror(cudaMemcpyAsync(gs->d_visited_mask,
                                               vmask,
                                               visited_mask_bytes,
                                               cudaMemcpyHostToDevice,
                                               gs->stream
        ), "Copy of d_filer_mask to device failed", __FILE__, __LINE__);
    }
}

/*
 *  Expect symmetric partitioning
 */
void CUDA_BFS::getOutgoingFQ(vtxtyp globalstart, long size, vtxtyp *&startaddr, int &outsize) {
    typename MatrixT::vtxtyp *start_local;
    typename MatrixT::vtxtyp *end_local;

    // determine the local range for the reduction
    start_local = std::lower_bound(queuebuff, queuebuff + qb_length, globalstart,
                                   [](vtxtyp a, vtxtyp b) { return a < (b & Csr::ProblemType::VERTEX_ID_MASK); });
    end_local = std::upper_bound(start_local, queuebuff + qb_length, globalstart + size - 1,
                                 [](vtxtyp a, vtxtyp b) { return b > (a & Csr::ProblemType::VERTEX_ID_MASK); });

#ifdef _DEBUG
    CheckQueue<vtxtyp>::ErrorCode errorCode;
    if((errorCode=checkQueue.checkCol(start_local, end_local-start_local))!= CheckQueue<vtxtyp>::ErrorCode::Valid){
        std::cerr << "(" <<store.getLocalRowID() << ":" <<store.getLocalColumnID() << ") ";
        switch(errorCode){
            case CheckQueue<vtxtyp>::ErrorCode::InvalidLength:
            std::cerr << "Select queue with invalid length";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::IdsOutOfRange:
            std::cerr << "Select queue with ids out of range";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::NotSorted:
            std::cerr << "Select not sorted queue";
            break;
            case CheckQueue<vtxtyp>::ErrorCode::DuplicteIds:
            std::cerr << "Select queue with duplicate ids";
            break;
            default:
            std::cerr << "Select invalid queue";
        }
        std::cerr << "." << std::endl;
    }
#endif

    startaddr = start_local;
    outsize = end_local - start_local;
}

/*  Sets the incoming FQ.
 *  Expect symmetric partitioning, so all parameters are ignored.
 */
void CUDA_BFS::setIncommingFQ(vtxtyp globalstart, long size, vtxtyp *startaddr, int &insize_max) {
    if (startaddr == recv_fq_buff) {
        std::swap(recv_fq_buff, queuebuff);
    }
    qb_length = insize_max;
}

bool CUDA_BFS::istheresomethingnew() {
    return !done;
}

void CUDA_BFS::getBackPredecessor() {
    //terminate all operations
    long sizeOfMType, storeColLength;

    bfsGPU->testOverflow(*csr_problem);
    b40c::util::B40CPerror(csr_problem->ExtractResults(predecessor, store.localtoglobalRow(0)),
                           "Extraction of result failed", __FILE__, __LINE__);
    bfsGPU->finalize();
    sizeOfMType = 8 * sizeof(MType);
    storeColLength = store.getLocColLength();

#ifdef _OPENMP
    #pragma omp parallel for
#endif

    for (long i = 0; i < mask_size; ++i) {
        MType tmp = 0;
        int isize = i * sizeOfMType;
        for (long j = 0; j < sizeOfMType; ++j) {
            int jsize = isize + j;
            const vtxtyp pred = predecessor[jsize];
            if ((pred != -1) && ((jsize) < storeColLength)) {
                tmp |= 1 << j;
                if (pred > -2) {
                    predecessor[jsize] = store.localtoglobalRow(
                            pred & Csr::ProblemType::VERTEX_ID_MASK);
                } else {
                    predecessor[jsize] = store.localtoglobalCol(jsize);
                }
            }
        }
        owenmask[i] = tmp;
    }
}

void CUDA_BFS::getBackOutqueue() {
    long queue_sizes[csr_problem->num_gpus];
    int numGpus;
    numGpus = csr_problem->num_gpus;

#ifdef _DEBUG
    b40c::util::B40CPerror(bfsGPU->testOverflow(csr_problem));
#endif

    //get length of next queues
#ifdef _OPENMP
    #pragma omp parallel for
#endif

    for (int i = 0; i < numGpus; ++i) {
        Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        queue_sizes[i] = bfsGPU->getQueueSize(gs->gpu, gs->stream);
        b40c::util::B40CPerror(cudaStreamSynchronize(gs->stream),
                               "Can't synchronize device.", __FILE__, __LINE__);
    }
    //sort values on the gpu
    for (int i = 0; i < numGpus; ++i) {
        typename Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        b40c::util::B40CPerror(cudaSetDevice(gs->gpu));
        thrust::device_ptr <typename MatrixT::vtxtyp> multigpu(gs->frontier_queues.d_keys[0]);
        thrust::sort(multigpu, multigpu + queue_sizes[i]);
    }

    qb_length = 0;//csr_problem->num_gpus;
    typename MatrixT::vtxtyp *qb_nxt = queuebuff;
    // copy next queue to host
    for (int i = 0; i < numGpus; ++i) {
        typename Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        b40c::util::B40CPerror(cudaStreamSynchronize(gs->stream),
                               "Can't synchronize device.", __FILE__, __LINE__);
        b40c::util::B40CPerror(cudaMemcpyAsync(qb_nxt,
                                               gs->frontier_queues.d_keys[0],
                                               queue_sizes[i] * sizeof(typename Csr::VertexId),
                                               cudaMemcpyDeviceToHost,
                                               gs->stream
        ), "Copy of d_keys[0] failed", __FILE__, __LINE__);
        qb_nxt += queue_sizes[i];
        qb_length += queue_sizes[i];
    }

    //#pragma omp parallel for
    for (int i = 0; i < numGpus; ++i) {
        Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        b40c::util::B40CPerror(cudaStreamSynchronize(gs->stream),
                               "Can't synchronize Stream.", __FILE__, __LINE__);
    }

    // Queue preprocessing
    //Uniqueness
    typename MatrixT::vtxtyp *qb_nxt_in = queuebuff;
    typename MatrixT::vtxtyp *qb_nxt_out = redbuff;
    for (int i = 0; i < numGpus; ++i) {
        typename MatrixT::vtxtyp *start_in = std::upper_bound(qb_nxt_in, qb_nxt_in + queue_sizes[i], -1);
        typename MatrixT::vtxtyp *end_out = std::unique_copy(start_in, qb_nxt_in + queue_sizes[i], qb_nxt_out);
        qb_nxt_in += queue_sizes[i];
        qb_nxt_out = end_out;
    }
    qb_length = qb_nxt_out - redbuff;
    std::swap(queuebuff, redbuff);
#ifdef _DEBUG
    CheckQueue<vtxtyp>::ErrorCode errorCode;
    if((errorCode=checkQueue.checkCol(queuebuff, qb_length))!= CheckQueue<vtxtyp>::ErrorCode::Valid){
        std::cerr << "(" <<store.getLocalRowID() << ":" <<store.getLocalColumnID() << ") ";
        switch(errorCode){
            case CheckQueue<vtxtyp>::ErrorCode::InvalidLength:
            std::cerr << "Got queue with invalid length from the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::IdsOutOfRange:
            std::cerr << "Got queue with ids out of range from the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::NotSorted:
            std::cerr << "Got not sorted queue from the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::DuplicteIds:
            std::cerr << "Got queue with duplicate ids from the device." << std::endl;
            break;
            default:
            std::cerr << "Got invalid queue from the device." << std::endl;
        }
    }
#endif
}

void CUDA_BFS::setBackInqueue() {
    long queue_sizes[csr_problem->num_gpus];
    typename MatrixT::vtxtyp *qb_nxt = queuebuff;
    typename MatrixT::vtxtyp *end_local;
    typename Csr::GraphSlice *gs;
    int numGpus = csr_problem->num_gpus;

#ifdef _DEBUG
    CheckQueue<vtxtyp>::ErrorCode errorCode;
    if((errorCode=checkQueue.checkRow(queuebuff, qb_length))!= CheckQueue<vtxtyp>::ErrorCode::Valid){
        std::cerr << "(" <<store.getLocalRowID() << ":" <<store.getLocalColumnID() << ") ";
        switch(errorCode){
            case CheckQueue<vtxtyp>::ErrorCode::InvalidLength:
            std::cerr << "Try to copy queue with invalid length to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::IdsOutOfRange:
            std::cerr << "Try to copy queue with ids out of range to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::NotSorted:
            std::cerr << "Try to copy not sorted queue to the device." << std::endl;
            break;
            case CheckQueue<vtxtyp>::ErrorCode::DuplicteIds:
            std::cerr << "Try to copy queue with duplicate ids to the device." << std::endl;
            break;
            default:
            std::cerr << "Try to copy invalid queue to the device." << std::endl;
        }
    }
#endif

    // copy next queue to device
    for (int i = 0; i < numGpus; ++i) {
        gs = csr_problem->graph_slices[i];

        //determine end of own slice
        end_local = std::upper_bound(qb_nxt, queuebuff + qb_length, gs->gpu,
                                     [](vtxtyp a, vtxtyp b) {
                                         return b < ((a & Csr::ProblemType::GPU_MASK) >>
                                                     Csr::ProblemType::GPU_MASK_SHIFT);
                                     });
        queue_sizes[i] = end_local - qb_nxt;

        b40c::util::B40CPerror(cudaMemcpyAsync(gs->frontier_queues.d_keys[0],
                                               qb_nxt,
                                               queue_sizes[i] * sizeof(typename Csr::VertexId),
                                               cudaMemcpyHostToDevice,
                                               gs->stream
        ), "Copy of d_keys[0] from device failed", __FILE__, __LINE__);
        qb_nxt = end_local;
    }

    //set length of current queue
#ifdef _OPENMP
    #pragma omp parallel for
#endif

    for (int i = 0; i < numGpus; ++i) {
        typename Csr::GraphSlice *gs = csr_problem->graph_slices[i];
        bfsGPU->setQueueSize(i, static_cast<typename Csr::SizeT>(queue_sizes[i]), gs->stream);
        b40c::util::B40CPerror(cudaStreamSynchronize(gs->stream),
                               "Can't synchronize device.", __FILE__, __LINE__);
    }
}

void CUDA_BFS::setStartVertex(vtxtyp start) {
    done = false;
    vtxtyp src_owner, rstart, lstart = -1;
    typename Csr::GraphSlice *gs;
    int cpro_verbosity = 0, numGpus, visited_mask_bytes;

    numGpus = csr_problem->num_gpus;

#ifdef INSTRUMENTED
    if (verbosity >= 24) {
        cpro_verbosity = 2;
    } else if (verbosity >= 8) {
        cpro_verbosity = 1;
    }
#endif

    if (b40c::util::B40CPerror(csr_problem->Reset(
            bfsGPU->GetFrontierType(),
            queue_sizing,
            cpro_verbosity
    ), "Reset error.", __FILE__, __LINE__) != cudaSuccess) {
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
    // Alloc and reset visited mask on host

    gs = csr_problem->graph_slices[0];

    visited_mask_bytes = ((csr_problem->nodes * sizeof(typename Csr::VisitedMask)) + 8 - 1) / 8;
    if (vmask == 0) {
        cudaHostAlloc(&vmask, visited_mask_bytes, cudaHostAllocDefault);
    }
    std::fill_n(vmask, visited_mask_bytes, 0);

    if (store.isLocalColumn(start)) {
        lstart = store.globaltolocalCol(start);
        vmask[lstart >> 3] = 1 << (lstart & 0x7);
    }

    //new next queue
    qb_length = 0;

    if (store.isLocalRow(start)) {
        rstart = store.globaltolocalRow(start);
        src_owner = csr_problem->GpuIndex(rstart);
        rstart |= (src_owner << Csr::ProblemType::GPU_MASK_SHIFT);

        queuebuff[0] = rstart;
        qb_length = 1;
    }

    if (b40c::util::B40CPerror(bfsGPU->EnactSearch(
            *csr_problem,
            lstart
    ), "Start error.", __FILE__, __LINE__) != cudaSuccess) {
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    for (int i = 0; i < numGpus; ++i) {
        //set new visited map
        gs = csr_problem->graph_slices[i];
        b40c::util::B40CPerror(cudaMemcpyAsync(gs->d_visited_mask,
                                               vmask,
                                               visited_mask_bytes,
                                               cudaMemcpyHostToDevice,
                                               gs->stream
        ), "Copy of d_filer_mask from device failed", __FILE__, __LINE__);
        // set new current queue
        if (store.isLocalRow(start) &&
            (((queuebuff[0] & Csr::ProblemType::GPU_MASK) >> Csr::ProblemType::GPU_MASK_SHIFT) == i)) {
            b40c::util::B40CPerror(cudaMemcpyAsync(gs->frontier_queues.d_keys[0],
                                                   &queuebuff[0],
                                                   sizeof(typename Csr::VertexId),
                                                   cudaMemcpyHostToDevice,
                                                   gs->stream
            ), "Copy of d_keys[0] from device failed", __FILE__, __LINE__);
            bfsGPU->setQueueSize(i, static_cast<typename Csr::SizeT>(1), gs->stream);
        } else {
            bfsGPU->setQueueSize(i, static_cast<typename Csr::SizeT>(0), gs->stream);
        }
    }
}

void CUDA_BFS::runLocalBFS() {
    int numGpus = csr_problem->num_gpus;

    //finish outstanding copys
    for (int i = 0; i < numGpus; ++i) {
        cudaStreamSynchronize(csr_problem->graph_slices[i]->stream);
    }
    //enact expansion kernel
    if (b40c::util::B40CPerror(bfsGPU->EnactIteration(
            *csr_problem,
            done
    ), "Iteration error.", __FILE__, __LINE__) != cudaSuccess) {
        MPI_Abort(MPI_COMM_WORLD, 1);
    }
}
