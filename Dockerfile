FROM ubuntu:22.04

ARG MASTER
ARG USER_ID=1000
ARG GROUP_ID=1000

# Prepare and empty machine for building:
RUN apt-get update -yq
RUN apt-get -yq install build-essential git cmake libpng-dev libjpeg-dev libtiff-dev libglu1-mesa-dev libxxf86vm1 libxxf86vm-dev libxi-dev libxrandr-dev libomp-dev

# Eigen 
RUN git clone https://gitlab.com/libeigen/eigen --branch 3.4
RUN mkdir eigen_build
RUN cd eigen_build &&\
	cmake . ../eigen &&\
	make && make install &&\
	cd ..

# Boost
RUN apt-get -y install libboost-iostreams-dev libboost-program-options-dev libboost-system-dev libboost-serialization-dev

# OpenCV
RUN DEBIAN_FRONTEND=noninteractive apt-get install -yq libopencv-dev

# CGAL
RUN apt-get -yq install libcgal-dev libcgal-qt5-dev

# VCGLib
RUN git clone https://github.com/cdcseacave/VCG.git vcglib

# Ceres
RUN apt-get -y install libatlas-base-dev libsuitesparse-dev ; \
	git clone https://ceres-solver.googlesource.com/ceres-solver ceres-solver ; \
	mkdir ceres_build && cd ceres_build ; \
	cmake . ../ceres-solver/ -DMINIGLOG=ON -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF ; \
	make -j2 && make install ; \
	cd ..; \
	rm -rf ceres-solver; rm -rf ceres_build

# Clean up
RUN apt-get autoclean && apt-get clean

# Build latest openMVG
RUN git clone --recursive https://github.com/openMVG/openMVG.git ; \
	mkdir openMVG_build && cd openMVG_build; \
	cmake -DCMAKE_BUILD_TYPE=RELEASE \
	-DOpenMVG_BUILD_TESTS=OFF \
	-DOpenMVG_BUILD_EXAMPLES=OFF \
	-DOpenMVG_BUILD_DOC=OFF \
	-DTARGET_ARCHITECTURE=generic \
	../openMVG/src; \
	cmake --build . --target install; \
	cd ..; \
	cp /openMVG_build/bin/* /bin
# rm -rf /openMVG; rm -rf /openMVG_build

# Build from stable openMVS release or the latest commit from the develop branch
RUN if [[ -n "$MASTER" ]] ; then git clone https://github.com/cdcseacave/openMVS.git --branch master ; else git clone https://github.com/cdcseacave/openMVS.git --branch develop ; fi

RUN mkdir openMVS_build
RUN cd openMVS_build &&\
	cmake . ../openMVS -DCMAKE_BUILD_TYPE=Release -DVCG_ROOT=/vcglib -DOpenMVS_USE_CUDA=OFF

# Install OpenMVS library
RUN cd openMVS_build &&\
	make -j4 &&\
	make install

RUN chmod +x /openMVS/MvgMvsPipeline.py 
RUN cp -r /openMVS_build/bin/* /bin; cp /openMVS/MvgMvsPipeline.py /bin/MvgMvsPipeline.py ; rm -rf /openMVS; rm -rf /openMVS_build
RUN ln -s /bin/MvgMvsPipeline.py /usr/local/bin/mvgmvs

# Set permissions such that the output files can be accessed by the current user (optional)
RUN addgroup --gid $GROUP_ID user &&\
	adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
USER user

# Add binaries to path
ENV PATH /usr/local/bin/OpenMVS:$PATH