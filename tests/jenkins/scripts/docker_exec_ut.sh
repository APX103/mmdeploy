#!/bin/bash

## keep container alive
nohup sleep infinity > sleep.log 2>&1 &

## init conda
__conda_setup="$('/opt/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        . "/opt/conda/etc/profile.d/conda.sh"
    else
        export PATH="/opt/conda/bin:$PATH"
    fi
fi
unset __conda_setup

# install sys libs
apt-get install lcov

## parameters
export codebase=$1

export MMDEPLOY_DIR=/root/workspace/mmdeploy
#### TODO: to be removed
export LD_LIBRARY_PATH=$ONNXRUNTIME_DIR/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH/\/root\/workspace\/libtorch\/lib:/}

for TORCH_VERSION in 1.10.0 1.11.0
do
    conda activate torch${TORCH_VERSION}
    # export libtorch cmake dir, ran example: /opt/conda/envs/torch1.11.0/lib/python3.8/site-packages/torch/share/cmake/Torch
    export Torch_DIR=$(python -c "import torch;print(torch.utils.cmake_prefix_path + '/Torch')")
    # need to build for each env
    # TODO add openvino
    mkdir -p $MMDEPLOY_DIR/build && cd $MMDEPLOY_DIR/build
    cmake .. -DMMDEPLOY_BUILD_SDK=ON \
            -DMMDEPLOY_BUILD_EXAMPLES=ON \
            -DMMDEPLOY_BUILD_SDK_MONOLITHIC=ON -DMMDEPLOY_BUILD_TEST=ON \
            -DMMDEPLOY_BUILD_SDK_PYTHON_API=ON -DMMDEPLOY_BUILD_SDK_JAVA_API=ON \
            -DMMDEPLOY_COVERAGE=ON \
            -DMMDEPLOY_BUILD_EXAMPLES=ON -DMMDEPLOY_ZIP_MODEL=ON \
            -DMMDEPLOY_TARGET_BACKENDS="trt;ort;ncnn" \
            -DMMDEPLOY_SHARED_LIBS=OFF \
            -DTENSORRT_DIR=${TENSORRT_DIR} \
            -DCUDNN_DIR=${CUDNN_DIR} \
            -DONNXRUNTIME_DIR=${ONNXRUNTIME_DIR} \
            -Dncnn_DIR=${ncnn_DIR} \
            -DTorch_DIR=${Torch_DIR} \
            -Dpplcv_DIR=${pplcv_DIR} \
            -DMMDEPLOY_TARGET_DEVICES="cuda;cpu"

    make -j $(nproc) && make install

    # sdk tests
    mkdir -p mmdeploy_test_resources/transform
    cp ../tests/data/tiger.jpeg mmdeploy_test_resources/transform/
    ./bin/mmdeploy_tests
    lcov --capture --directory . --output-file coverage.info
    ls -lah coverage.info
    cp coverage.info $MMDEPLOY_DIR/../ut_log/${TORCH_VERSION}_sdk_ut_converage.info

    cd $MMDEPLOY_DIR
    pip install openmim
    pip install -r requirements/tests.txt
    pip install -r requirements/runtime.txt
    pip install -r requirements/build.txt
    pip install -v .
    ## build ${codebase}
    if [ ${codebase} == mmdet3d ]; then
        mim install ${codebase}
        mim install mmcv-full==1.5.2
    elif [ ${codebase} == mmedit ]; then
        mim install ${codebase}
        mim install mmcv-full==1.6.0
    elif [ ${codebase} == mmrotate ]; then
        mim install ${codebase}
        mim install mmcv-full==1.6.0
    else
        mim install ${codebase}
        if [ $? -ne 0 ]; then
            mim install mmcv-full
        fi
    fi
    ## start python tests
    coverage run --branch --source mmdeploy -m pytest -rsE tests
    coverage xml
    coverage report -m
    cp coverage.xml $MMDEPLOY_DIR/../ut_log/${TORCH_VERSION}_converter_converage.xml
done
