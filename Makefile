#############################################################################
# Makefile for building: g500
# Generated by qmake (3.0) (Qt 5.0.2) on: Mi. Feb. 19 15:58:02 2014
# Project:  g500.pro
# Template: app
# Command: /usr/lib/x86_64-linux-gnu/qt5/bin/qmake -o Makefile g500.pro
#############################################################################

MAKEFILE      = Makefile

####### Compiler, tools and options

CC            = mpicc
CXX           = mpicxx
DEFINES       = 
CFLAGS        = -m64 -pipe -I/usr/lib/openmpi/include -I/usr/lib/openmpi/include/openmpi -pthread -std=c99 -fopenmp -O2 -O3 -Wall -W -fPIE $(DEFINES)
CXXFLAGS      = -m64 -pipe -I/usr/lib/openmpi/include -I/usr/lib/openmpi/include/openmpi -pthread -DMPICH_IGNORE_CXX_SEEK -fopenmp -O2 -O3 -Wall -W -fPIE $(DEFINES)
INCPATH       = -I/usr/share/qt5/mkspecs/linux-g++-64 -I.
LINK          = mpicxx
LFLAGS        = -m64 -pthread -L/usr//lib -L/usr/lib/openmpi/lib -lmpi_cxx -lmpi -ldl -lhwloc -fopenmp -Wl,-O1
LIBS          = $(SUBLIBS)  
AR            = ar cqs
RANLIB        = 
QMAKE         = /usr/lib/x86_64-linux-gnu/qt5/bin/qmake
TAR           = tar -cf
COMPRESS      = gzip -9f
COPY          = cp -f
SED           = sed
COPY_FILE     = cp -f
COPY_DIR      = cp -f -R
STRIP         = strip
INSTALL_FILE  = install -m 644 -p
INSTALL_DIR   = $(COPY_DIR)
INSTALL_PROGRAM = install -m 755 -p
DEL_FILE      = rm -f
SYMLINK       = ln -f -s
DEL_DIR       = rmdir
MOVE          = mv -f
CHK_DIR_EXISTS= test -d
MKDIR         = mkdir -p

####### Output directory

OBJECTS_DIR   = ./

####### Files

SOURCES       = main.cpp \
		distmatrix2d.cpp \
		generator/utils.c \
		generator/splittable_mrg.c \
		generator/make_graph.c \
		generator/graph_generator.c \
		globalbfs.cpp \
		simplecpubfs.cpp \
		validate/onesided.c \
		validate/onesided_emul.c \
		validate/validate.cpp 
OBJECTS       = main.o \
		distmatrix2d.o \
		utils.o \
		splittable_mrg.o \
		make_graph.o \
		graph_generator.o \
		globalbfs.o \
		simplecpubfs.o \
		onesided.o \
		onesided_emul.o \
		validate.o
DIST          = /usr/share/qt5/mkspecs/features/spec_pre.prf \
		/usr/share/qt5/mkspecs/common/shell-unix.conf \
		/usr/share/qt5/mkspecs/common/unix.conf \
		/usr/share/qt5/mkspecs/common/linux.conf \
		/usr/share/qt5/mkspecs/common/gcc-base.conf \
		/usr/share/qt5/mkspecs/common/gcc-base-unix.conf \
		/usr/share/qt5/mkspecs/common/g++-base.conf \
		/usr/share/qt5/mkspecs/common/g++-unix.conf \
		/usr/share/qt5/mkspecs/qconfig.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_bootstrap.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_concurrent.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_core.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_dbus.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_gui.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_network.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_opengl.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_platformsupport.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_printsupport.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_qml.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_qmldevtools.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_qmltest.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_quick.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_quickparticles.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_sql.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_testlib.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_widgets.pri \
		/usr/share/qt5/mkspecs/modules/qt_lib_xml.pri \
		/usr/share/qt5/mkspecs/features/qt_functions.prf \
		/usr/share/qt5/mkspecs/features/qt_config.prf \
		/usr/share/qt5/mkspecs/linux-g++-64/qmake.conf \
		/usr/share/qt5/mkspecs/features/spec_post.prf \
		/usr/share/qt5/mkspecs/features/exclusive_builds.prf \
		/usr/share/qt5/mkspecs/features/default_pre.prf \
		/usr/share/qt5/mkspecs/features/unix/default_pre.prf \
		/usr/share/qt5/mkspecs/features/resolve_config.prf \
		/usr/share/qt5/mkspecs/features/default_post.prf \
		/usr/share/qt5/mkspecs/features/unix/gdb_dwarf_index.prf \
		/usr/share/qt5/mkspecs/features/warn_on.prf \
		/usr/share/qt5/mkspecs/features/wayland-scanner.prf \
		/usr/share/qt5/mkspecs/features/testcase_targets.prf \
		/usr/share/qt5/mkspecs/features/exceptions.prf \
		/usr/share/qt5/mkspecs/features/yacc.prf \
		/usr/share/qt5/mkspecs/features/lex.prf \
		g500.pro \
		g500.pro
QMAKE_TARGET  = g500
DESTDIR       = 
TARGET        = g500


first: all
####### Implicit rules

.SUFFIXES: .o .c .cpp .cc .cxx .C

.cpp.o:
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o "$@" "$<"

.cc.o:
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o "$@" "$<"

.cxx.o:
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o "$@" "$<"

.C.o:
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o "$@" "$<"

.c.o:
	$(CC) -c $(CFLAGS) $(INCPATH) -o "$@" "$<"

####### Build rules

all: Makefile $(TARGET)

$(TARGET):  $(OBJECTS)  
	$(LINK) $(LFLAGS) -o $(TARGET) $(OBJECTS) $(OBJCOMP) $(LIBS)

qmake: FORCE
	@$(QMAKE) -o Makefile g500.pro

qmake_all: FORCE

dist: 
	@test -d .tmp/g5001.0.0 || mkdir -p .tmp/g5001.0.0
	$(COPY_FILE) --parents $(SOURCES) $(DIST) .tmp/g5001.0.0/ && (cd `dirname .tmp/g5001.0.0` && $(TAR) g5001.0.0.tar g5001.0.0 && $(COMPRESS) g5001.0.0.tar) && $(MOVE) `dirname .tmp/g5001.0.0`/g5001.0.0.tar.gz . && $(DEL_FILE) -r .tmp/g5001.0.0


clean:compiler_clean 
	-$(DEL_FILE) $(OBJECTS)
	-$(DEL_FILE) *~ core *.core


####### Sub-libraries

distclean: clean
	-$(DEL_FILE) $(TARGET) 
	-$(DEL_FILE) Makefile


check: first

compiler_wayland-server-header_make_all:
compiler_wayland-server-header_clean:
compiler_wayland-client-header_make_all:
compiler_wayland-client-header_clean:
compiler_wayland-code_make_all:
compiler_wayland-code_clean:
compiler_yacc_decl_make_all:
compiler_yacc_decl_clean:
compiler_yacc_impl_make_all:
compiler_yacc_impl_clean:
compiler_lex_make_all:
compiler_lex_clean:
compiler_clean: 

####### Compile

main.o: main.cpp generator/make_graph.h \
		generator/graph_generator.h \
		generator/user_settings.h \
		validate/validate.h \
		distmatrix2d.h \
		validate/mpi_workarounds.h \
		simplecpubfs.h \
		globalbfs.h
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o main.o main.cpp

distmatrix2d.o: distmatrix2d.cpp distmatrix2d.h \
		generator/graph_generator.h \
		generator/user_settings.h
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o distmatrix2d.o distmatrix2d.cpp

utils.o: generator/utils.c generator/splittable_mrg.h \
		generator/graph_generator.h \
		generator/user_settings.h \
		generator/utils.h
	$(CC) -c $(CFLAGS) $(INCPATH) -o utils.o generator/utils.c

splittable_mrg.o: generator/splittable_mrg.c generator/mod_arith.h \
		generator/user_settings.h \
		generator/mod_arith_64bit.h \
		generator/mod_arith_32bit.h \
		generator/splittable_mrg.h \
		generator/mrg_transitions.c
	$(CC) -c $(CFLAGS) $(INCPATH) -o splittable_mrg.o generator/splittable_mrg.c

make_graph.o: generator/make_graph.c generator/graph_generator.h \
		generator/user_settings.h \
		generator/utils.h \
		generator/splittable_mrg.h
	$(CC) -c $(CFLAGS) $(INCPATH) -o make_graph.o generator/make_graph.c

graph_generator.o: generator/graph_generator.c generator/user_settings.h \
		generator/splittable_mrg.h \
		generator/graph_generator.h
	$(CC) -c $(CFLAGS) $(INCPATH) -o graph_generator.o generator/graph_generator.c

globalbfs.o: globalbfs.cpp globalbfs.h \
		distmatrix2d.h \
		generator/graph_generator.h \
		generator/user_settings.h
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o globalbfs.o globalbfs.cpp

simplecpubfs.o: simplecpubfs.cpp simplecpubfs.h \
		globalbfs.h \
		distmatrix2d.h \
		generator/graph_generator.h \
		generator/user_settings.h
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o simplecpubfs.o simplecpubfs.cpp

onesided.o: validate/onesided.c validate/mpi_workarounds.h \
		validate/onesided.h \
		generator/utils.h \
		generator/splittable_mrg.h
	$(CC) -c $(CFLAGS) $(INCPATH) -o onesided.o validate/onesided.c

onesided_emul.o: validate/onesided_emul.c validate/mpi_workarounds.h \
		validate/onesided.h
	$(CC) -c $(CFLAGS) $(INCPATH) -o onesided_emul.o validate/onesided_emul.c

validate.o: validate/validate.cpp distmatrix2d.h \
		generator/graph_generator.h \
		generator/user_settings.h \
		validate/validate.h \
		validate/mpi_workarounds.h \
		generator/utils.h \
		generator/splittable_mrg.h \
		validate/onesided.h
	$(CXX) -c $(CXXFLAGS) $(INCPATH) -o validate.o validate/validate.cpp

####### Install

install:   FORCE

uninstall:   FORCE

FORCE:

