param(
    $codebase,
    $exec_performance,
    $codebase_fullname,
    $mmdeploy_branch
)
$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
$confDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $scriptDir\utils.psm1
$json_v1 = (Get-Content "$confDir\requirementV1.0.json")
$json_v2 = (Get-Content "$confDir\requirementV2.0.json")
cd $env:MMDEPLOY_DIR
conda activate mmdeploy-3.7-cu113
Write-Host "exec_path: $pwd"
Write-Host "mim install $codebase"
Write-Host "codebase_fullname = $codebase_fullname"
Write-Host "exec_performance = $exec_performance"
Write-Host "mmdeploy_branch = $mmdeploy_branch"
$codebase_path = (Join-Path $env:JENKINS_WORKSPACE $codebase_fullname)
Write-Host "codebase_path = $codebase_path"
$log_dir = (Join-Path $env:WORKSPACE "mmdeploy_regression_working_dir\$codebase\$env:CUDA_VERSION")
Write-Host "log_dir = $log_dir"
InitMim $codebase $codebase_fullname $mmdeploy_branch
pip uninstall mmcv-full -y
pip uninstall mmcv -y
pip uninstall $codebase -y
if ($mmdeploy_branch -eq "master"){
    if ($codebase -eq "mmdet3d")
    {
        mim install mmcv-full==1.5.2
    }
    else
    {
        mim install mmcv-full == 1.6.0
    }
}
else{
    mim install mmcv== 2.0.0rc4
}

mim install $codebase
pip install -v $codebase_path
pip uninstall mmcv-full==1.7.1 -y
Write-Host "$pwd"
#Invoke-Expression -Command "python3 ./tools/regression_test.py --codebase $codebase --device cuda:0 --backends tensorrt onnxruntime --work-dir $log_dir  $exec_performance"
# python3 ./tools/regression_test.py --codebase $codebase --device cuda:0 --backends tensorrt onnxruntime --work-dir $log_dir  $exec_performance
python $pwd/tools/regression_test.py `
    --codebase $codebase `
    --device cuda:0 `
    --backends tensorrt onnxruntime `
    --work-dir $log_dir  `
    $exec_performance

if (-not $?) {
    throw "regression_test failed"
}
