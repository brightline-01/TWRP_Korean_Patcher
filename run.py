import os
import subprocess
import sys
import shutil
import tarfile
import stat

Vbmeta_Path = None
Original_Name = None
MagiskBoot_Path = os.path.abspath(os.path.join("Binary", "magiskboot.exe"))
Input_TWRP_File = None

def Initialize():
    global Vbmeta_Path
    global Original_Name
    global Input_TWRP_File

    InputDir = "Input_TWRP"

    if not os.path.exists(InputDir):
        os.makedirs(InputDir)
        print ("[오류] Input_TWRP 폴더에 TWRP 파일을 삽입한 후 다시 실행해주세요.")
        sys.exit(1)

    Files = os.listdir(InputDir)
    IMG_Files = [f for f in Files if f.lower().endswith(".img")]
    TAR_Files = [f for f in Files if f.lower().endswith(".tar")]

    if IMG_Files:
        Input_TWRP_File = "IMG"
        print(f"[정보] TWRP 파일을 감지했습니다: {IMG_Files[0]}")
        Original_Name = IMG_Files[0].replace(".img", "")
        return os.path.join(InputDir, IMG_Files[0])
        
    if TAR_Files:
        Input_TWRP_File = "TAR"
        TAR_Path = os.path.join(InputDir, TAR_Files[0])
        Extract_Path = os.path.join(InputDir, "Extracted")
        
        os.makedirs(Extract_Path, exist_ok=True)
        print(f"[정보] TWRP 파일을 감지했습니다: {TAR_Files[0]}")

        Original_Name = TAR_Files[0].replace(".tar", "")

        print("[작업] Tar 파일을 압축 해제하는 중...")

        with tarfile.open(TAR_Path, "r") as tar:
            tar.extractall(path=Extract_Path, filter="data")

        Extracted_Files = os.listdir(Extract_Path)

        for f in Extracted_Files:
            if f.lower() == "vbmeta.img":
                Vbmeta_Path = os.path.join(Extract_Path, f)
                print("[정보] vbmeta.img 이미지를 감지했습니다. 다시 압축 시 같이 압축합니다.")

        Extracted_IMG = [f for f in Extracted_Files if f.lower().endswith(".img") and f.lower() != "vbmeta.img"]

        if not Extracted_IMG:
            print("[오류] TWRP 파일이 손상되었습니다.")
            sys.exit(1)

        print(f"[정보] 추출된 이미지 파일: {Extracted_IMG[0]}")
        return os.path.join(Extract_Path, Extracted_IMG[0])

    print("[정보] TWRP 파일(.tar 또는 .img)을 찾을 수 없습니다.")
    sys.exit(1)

def Unpack_IMG(IMG_Path):
    Workspace = "Workspace"
    RamdiskDir = os.path.join(Workspace, "ramdisk")

    os.makedirs(Workspace, exist_ok=True)
    os.makedirs(RamdiskDir, exist_ok=True)

    print("[작업] 이미지를 압축 해제하는 중...")

    result = subprocess.run([MagiskBoot_Path, "unpack", IMG_Path], cwd=Workspace, capture_output=True, text=True)

    if result.returncode != 0:
        print("[오류] 이미지를 압축 해제하는 데 실패했습니다.")
        print(result.stderr)
        sys.exit(1)

    print("[정보] 이미지를 성공적으로 압축 해제했습니다.")

    Ramdisk_File = None
    for f in os.listdir(Workspace):
        if f.startswith("ramdisk.cpio"):
            Ramdisk_File = f
            break

    if not Ramdisk_File:
        print("[오류] ramdisk 파일을 찾을 수 없습니다.")
        sys.exit(1)

    print("[작업] ramdisk 압축 해제 중...")

    result = subprocess.run([MagiskBoot_Path, "cpio", Ramdisk_File, "extract"], cwd=Workspace, capture_output=True, text=True)

    if result.returncode != 0:
        print("[오류] ramdisk 압축 해제에 실패했습니다.")
        print(result.stderr)
        sys.exit(1)

    print("[정보] ramdisk를 성공적으로 압축 해제했습니다.")
    return RamdiskDir

def Find_Twres(Ramdisk_Path):
    for root, dirs, files in os.walk(Ramdisk_Path):
        if "twres" in dirs:
            return os.path.join(root, "twres")
    return None

def Patch_Resources(Ramdisk_Path):
    ResourcesDir = "Resources"
    TwresDir = Find_Twres(Ramdisk_Path)

    if not os.path.exists(ResourcesDir):
        print("[오류] 패치 프로그램 손상이 감지되었습니다. 공식 GitHub에서 직접 다운로드해 주세요.")
        sys.exit(1)

    if not os.path.exists(TwresDir):
        print("[오류] 이미지 파일이 TWRP 파일이 아닙니다.")

    print("[작업] 리소스 병합 중...")

    shutil.copytree(ResourcesDir, TwresDir, dirs_exist_ok=True)

    print("[정보] 리소스 병합을 완료했습니다.")

def Repack_IMG(Original_IMG_Path):
    Workspace = "Workspace"

    print("[작업] 이미지를 다시 압축하는 중...")

    result = subprocess.run(
        [MagiskBoot_Path, "repack", Original_IMG_Path, f"{Original_Name}_Korean.img"],
        cwd=Workspace,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("[오류] 이미지를 압축하는 데 실패했습니다.")
        print(result.stderr)
        sys.exit(1)

    print("[정보] 이미지를 다시 압축했습니다.")

    Output_Path = os.path.join(Workspace, f"{Original_Name}_Korean.img")

    if not os.path.exists(Output_Path):
        print("[오류] 이미지 파일이 생성되지 않았습니다.")
        sys.exit(1)

    print(f"[완료] 패치된 TWRP: {Output_Path}")
    return Output_Path

def Repack_TAR(Recovery_IMG_Path):
    global Vbmeta_Path, Original_Name

    OutputDir = "Output_TWRP"
    if not os.path.exists(OutputDir):
        os.makedirs(OutputDir)

    TAR_Name = f"{Original_Name}_Korean.tar"
    TAR_Path = os.path.join(OutputDir, TAR_Name)

    print("[작업] Tar 파일로 압축하는 중...")

    with tarfile.open(TAR_Path, "w") as tar:
        tar.add(Recovery_IMG_Path, arcname="recovery.img")

        if Vbmeta_Path and os.path.exists(Vbmeta_Path):
            tar.add(Vbmeta_Path, arcname="vbmeta.img")
            print("[작업] vbmeta.img를 추가했습니다.")

    print(f"[정보] Tar 파일을 {TAR_Path}으로 저장했습니다.")
    return TAR_Path

def Remove_RO(func, path, _):
    os.chmod(path, stat.S_IWRITE)
    func(path)

def Cleanup(Patched_IMG_Path):
    Workspace = "Workspace"
    OutputDir = "Output_TWRP"
    Extract_Path = os.path.join("Input_TWRP", "Extracted")

    os.makedirs(OutputDir, exist_ok=True)

    if Input_TWRP_File == "IMG":
        if Patched_IMG_Path and os.path.exists(Patched_IMG_Path):
            DST_IMG = os.path.join(OutputDir, os.path.basename(Patched_IMG_Path))
            shutil.move(Patched_IMG_Path, DST_IMG)
            print(f"[정보] 이미지 파일을 {DST_IMG}으로 저장했습니다.")

    print("[작업] 정리하는 중...")

    if os.path.exists(Extract_Path):
        shutil.rmtree(Extract_Path)
        print("[정보] Extracted 폴더를 삭제했습니다.")

    if os.path.exists(Workspace):
        shutil.rmtree(Workspace, onerror=Remove_RO)
        print("[정보] Workspace 폴더를 삭제했습니다.")

    print("[완료] 정리를 완료했습니다.")

def Main_Patcher():
    print("*******************************************")
    print("=== TWRP 한국어 자동 패치를 시작합니다. ===")
    print("*******************************************")

    IMG_Path = Initialize()

    IMG_Path = os.path.abspath(IMG_Path)

    Ramdisk_Path = Unpack_IMG(IMG_Path)

    Patch_Resources(Ramdisk_Path)

    Patched_IMG = Repack_IMG(IMG_Path)

    if Input_TWRP_File == "TAR":
        Repack_TAR(Patched_IMG)

    Cleanup(Patched_IMG)

    print("*******************************************")
    print("=== 작업을 완료했습니다. ===")
    print("*******************************************")
    input("Enter 키를 눌러 종료하십시오...")

if __name__ == "__main__":
    Main_Patcher()