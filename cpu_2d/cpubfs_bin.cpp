#include <cstdlib>
#include <algorithm>
#include <assert.h>
#include "cpubfs_bin.h"

#if defined( __INTEL_COMPILER )
    #define assume_aligned(typ, var, alg) __assume_aligned(var, alg)
#elif defined( __GNUC__ )
    #define assume_aligned(typ, var, alg) var = (typ) __builtin_assume_aligned(var, alg)
#else
    #define assume_aligned(typ, var, alg)
#endif


CPUBFS_bin::CPUBFS_bin(MatrixT& _store):GlobalBFS<CPUBFS_bin,uint64_t,MatrixT>(_store),col64(_store.getLocColLength()/64),row64(_store.getLocRowLength()/64)
{
    fq_tp_type = MPI_UINT64_T; //Frontier Queue Transport Type
    //if(posix_memalign((void**)&predessor,64,sizeof(vtxtyp)*store.getLocColLength()))predessor=0;// new vtxtyp[store.getLocColLength()];;
    MPI_Alloc_mem(sizeof(vtxtyp)*store.getLocColLength(), MPI_INFO_NULL, (void*)(void*)&predessor);
    //allocate recive buffer
    long recv_fq_buff_length_tmp = std::max(store.getLocRowLength(), store.getLocColLength());
    recv_fq_buff_length = recv_fq_buff_length_tmp/64 + ((recv_fq_buff_length_tmp%64 >0)? 1:0);
    //if(posix_memalign((void**)&recv_fq_buff,64,sizeof(uint64_t)*recv_fq_buff_length))recv_fq_buff=0;
    MPI_Alloc_mem(sizeof(uint64_t)*recv_fq_buff_length, MPI_INFO_NULL, (void*)&recv_fq_buff);
    if(posix_memalign((void**)&visited,64,sizeof(uint64_t)*col64))visited=0;//new uint64_t[col64];
    //if(posix_memalign((void**)&fq_out,64,sizeof(uint64_t)*col64))fq_out=0; //new uint64_t[col64];
    MPI_Alloc_mem(sizeof(uint64_t)*col64, MPI_INFO_NULL, (void*)&fq_out);
    if(posix_memalign((void**)&fq_in,64,sizeof(uint64_t)*row64)) fq_in =0; //new uint64_t[row64];
}

CPUBFS_bin::~CPUBFS_bin()
{
    //free(predessor);
    MPI_Free_mem(predessor);

    //free(recv_fq_buff);
    MPI_Free_mem(recv_fq_buff);
    free(visited);
    //free(fq_out);
    MPI_Free_mem(fq_out);
    free(fq_in);
}


void CPUBFS_bin::reduce_fq_out(uint64_t* __restrict__ startaddr, long insize)
{
    //assume_aligned(uint64_t*,startaddr,64);
    //assume_aligned(uint64_t*,fq_out,64);

    assert(insize == col64);    
    for(long i = 0; i < col64; i++){
        fq_out[i] |= startaddr[i];
    }
}

void CPUBFS_bin::getOutgoingFQ(uint64_t *&startaddr, long &outsize)
{
   startaddr = fq_out;
   outsize  = col64;

}

void CPUBFS_bin::setModOutgoingFQ(uint64_t* __restrict__ startaddr, long insize)
{
   //assume_aligned(uint64_t*,startaddr,64);
   //assume_aligned(uint64_t*,fq_out,64);
   assume_aligned(uint64_t*,visited,64);

   assert(insize==col64);
   if(startaddr != 0)
       std::copy( startaddr, startaddr+col64, fq_out);
   for(long i = 0; i < col64; i++){
       visited[i] |=  fq_out[i];
   }
}

void CPUBFS_bin::getOutgoingFQ(vtxtyp globalstart, long size, uint64_t *&startaddr, long &outsize)
{
    startaddr = &fq_out[store.globaltolocalCol(globalstart)/64];
    outsize = size/64;
}

void CPUBFS_bin::setIncommingFQ(vtxtyp globalstart, long size, uint64_t* __restrict__ startaddr, long &insize_max)
{
    //assume_aligned(uint64_t*,startaddr,64);
    assert(insize_max >= size/64);
    std::copy(startaddr, startaddr+size/64, &fq_in[store.globaltolocalRow(globalstart)/64]);
}

bool CPUBFS_bin::istheresomethingnew()
{
    //assume_aligned(uint64_t*,fq_out,64);

    for(long i = 0; i < col64; i++){
        if(fq_out[i] > 0){
           return true;
        }
    }
    return false;
}

void CPUBFS_bin::setStartVertex(const vtxtyp start)
{
    assume_aligned(uint64_t*,fq_in,64);
    assume_aligned(uint64_t*,visited,64);
    std::fill_n( fq_in,   row64, 0);
    std::fill_n( visited, col64, 0);

    if(store.isLocalRow(start)){
        vtxtyp lstart = store.globaltolocalRow(start);
        fq_in[lstart/64] = 1ul << (lstart& 0x3F);
    }
     if(store.isLocalColumn(start)){
         vtxtyp lstart = store.globaltolocalCol(start);
         visited[lstart/64] = 1ul << (lstart&0x3F);
    }
    //reset predessor list
   //assume_aligned(vtxtyp*,predessor, 64);
   std::fill_n( predessor,   store.getLocColLength(), -1);

   if(store.isLocalColumn(start)){
        predessor[store.globaltolocalCol(start)] = start;
    }
}

void CPUBFS_bin::runLocalBFS()
{
    //assume_aligned(uint64_t*,fq_out,64);
    std::fill_n(fq_out, col64, 0);
    #pragma omp parallel for
    for(int64_t i = 0; i < row64 ; i++){
        if(fq_in[i] > 0){
        for(int ii = 0; ii < 64; ii++){
            if((fq_in[i]&1ul<<ii) > 0){
                const vtxtyp endrp = store.getRowPointer()[i*64+ii+1];
                for(vtxtyp j = store.getRowPointer()[i*64+ii]; j < endrp; j++){
                    vtxtyp visit_vtx_loc = store.getColumnIndex()[j];
                    if((visited[visit_vtx_loc>>6] & (1ul << (visit_vtx_loc &0x3F))) == 0 ){
                        if((fq_out[visit_vtx_loc>>6] & (1ul << (visit_vtx_loc &0x3F))) == 0 ){
                            uint64_t& fqn_ext = fq_out[visit_vtx_loc>>6];
                            uint64_t  setnext = 1ul << (visit_vtx_loc & 0x3F);
                            #pragma omp atomic
                            fqn_ext |= setnext;
                            predessor[visit_vtx_loc] = store.localtoglobalRow(i*64+ii);
                        }
                    }
                }
            }
        }
        }
    }
}
