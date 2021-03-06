##############################################
#                                            #
#        Makefile for Fortran-Library        #
#                                            #
##############################################

# Flags for user to tune
# Default to install to Fortran-Library
prefix = .
# intel and gnu compilers are supported
compiler = intel
flag = -O3

# User does not have to take care of following variables
gnumkl = -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_intel_lp64.a ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a ${MKLROOT}/lib/intel64/libmkl_core.a -Wl,--end-group -lgomp -lpthread -lm -ldl
gnumkl_sequential = -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_intel_lp64.a ${MKLROOT}/lib/intel64/libmkl_sequential.a ${MKLROOT}/lib/intel64/libmkl_core.a -Wl,--end-group -lpthread -lm -ldl
src = $(addprefix source/, StringUtility.f90 General.f90 Mathematics.f90 LinearAlgebra.f90 \
NonlinearOptimization.f90 IntegralTransform.f90 \
Clustering.f90 Statistics.f90 Chemistry.f90 \
GeometryTransformation.f90 \
FortranLibrary.f90 )
RealPrefix = $(realpath $(prefix))
incdir = $(RealPrefix)/include
libdir = $(RealPrefix)/lib

libFL.a libFL.so: $(src)
ifeq ($(compiler),intel)
	ifort -fpp -qopenmp -parallel -mkl -static-intel -ipo $(flag) -c $^
	xiar rcs libFL.a *.o
	rm *.o
	ifort -fpp -qopenmp -parallel -mkl -static-intel -ipo $(flag) -shared -fpic $^ -o libFL.so
else
	gfortran -fpp -fopenmp -ffree-line-length-0 -fno-range-check -I${MKLROOT}/include $(flag) -c $^
	ar rcs libFL.a *.o
	rm *.o
	gfortran -fpp -fopenmp -ffree-line-length-0 -fno-range-check -I${MKLROOT}/include $(flag) -shared -fpic $^ -o libFL.so
endif

.PHONY: install
install: | $(incdir) $(libdir)
	mv *.mod $(incdir)
	mv *.a  $(libdir)
	mv *.so $(libdir)
	cp cpp/*.hpp $(incdir)
ifneq ($(realpath .),$(RealPrefix))
	cp -r FortranLibrary $(RealPrefix)
endif

$(incdir):
	mkdir $(incdir)

$(libdir):
	mkdir $(libdir)

.PHONY: test
test:
ifeq ($(compiler),intel)
	ifort -qopenmp -parallel -mkl -static-intel -ipo $(flag) -I$(incdir) test/test.f90 $(libdir)/libFL.a -o test/test_static.exe
else
	gfortran -fopenmp -ffree-line-length-0 -fno-range-check -I${MKLROOT}/include $(flag) -I$(incdir) test/test.f90 -l:libFL.a $(gnumkl) -o test/test_static.exe
endif
	test/test_static.exe > test/log_static

ifeq (,$(findstring $(libdir),$(LIBRARY_PATH)))
$(error Please add prefix/lib to LIBRARY_PATH)
endif
ifeq (,$(findstring $(libdir),$(LD_LIBRARY_PATH)))
$(error Please add prefix/lib to LD_LIBRARY_PATH)
endif

ifeq ($(compiler),intel)
	ifort -qopenmp -parallel -mkl -static-intel -ipo $(flag) test/test.f90 -lFL -o test/test_dynamic.exe
else
	gfortran -fopenmp -ffree-line-length-0 -fno-range-check -I${MKLROOT}/include $(flag) -I$(incdir) test/test.f90 -lFL $(gnumkl) -o test/test_dynamic.exe
endif
	test/test_dynamic.exe > test/log_dynamic

ifeq (,$(findstring $(incdir),$(CPATH)))
$(error Please add prefix/include to CPATH)
endif
ifeq ($(compiler),intel)
	icpc -qopenmp -parallel -mkl -static-intel $(flag) test/test.cpp -lFL -o test/test_cpp.exe
else
	g++ -fopenmp -I${MKLROOT}/include $(flag) test/test.cpp -lFL $(gnumkl) -o test/test_cpp.exe
endif
	test/test_cpp.exe > test/log_cpp

ifeq (,$(findstring $(RealPrefix),$(PYTHONPATH)))
$(error Please add prefix to PYTHONPATH)
endif
	python test/test.py > test/log_py
