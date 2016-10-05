PWD=$(shell pwd)
RPM_BUILD_ROOT=build-dir
SRC_DIR=${PWD}/..

rpm: clean
	mkdir -p ${RPM_BUILD_ROOT}/usr/local/bin dist/RPMS dist/BUILD

	cp ${SRC_DIR}/dapi ${RPM_BUILD_ROOT}/usr/local/bin

	rpmbuild -bb --target=noarch-linux --define "_topdir ${PWD}/dist" --buildroot=${PWD}/${RPM_BUILD_ROOT} dapi-client-bash.spec

clean:
	rm -rf ${RPM_BUILD_ROOT}
	rm -rf dist
