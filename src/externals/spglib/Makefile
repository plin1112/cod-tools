BUILD_DIR = build
LIB       = ${BUILD_DIR}/libsymspg.a

all: ${LIB}

${LIB}:
	mkdir ${BUILD_DIR}
	(cd ${BUILD_DIR}; CFLAGS=-fPIC cmake ..)
	$(MAKE) -C ${BUILD_DIR}

cleanAll distclean:
	rm -rf ${BUILD_DIR}
