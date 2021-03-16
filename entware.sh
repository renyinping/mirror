#!/bin/sh


# wget 参数
# -N 除非远程文件较新，否则不再取回
# -c 断点续传
# -q 安静模式(不输出信息)
# -e https_proxy=http://127.0.0.1:1082/' 运行‘.wgetrc’形式的命令
WGET='wget -N -c -q -e http_proxy=http://127.0.0.1:1082/ -e https_proxy=http://127.0.0.1:1082/ '
PATH=./:$PATH


# 平台选择
ARCH='mipselsf-k3.4'
case $2 in 
    mipsel) ARCH='mipselsf-k3.4' ;;
    mips)   ARCH='mipssf-k3.4' ;;
    arm64)  ARCH='aarch64-k3.10' ;;
    x64)    ARCH='x64-k3.2' ;;
    x86)    ARCH='x86-k2.6' ;;
    *)      ;;
esac


# 全局控制
BASE_URL="http://bin.entware.net/${ARCH}"
BASE_DIR="entware/${ARCH}"
PACKAGES="${BASE_DIR}/Packages"


# 准备文件
ready_file=${ready_file}'installer/generic.sh '
ready_file=${ready_file}'installer/opkg '
ready_file=${ready_file}'installer/opkg.conf '
ready_file=${ready_file}'Packages.gz'

mkdir -p "${BASE_DIR}/" "${BASE_DIR}/installer/"


# 1. 下载文件名
# 2. 保存文件的附加后缀
dl() {

    #[ -f "${BASE_DIR}/${1}${2}" ] && return 0

    echo "--------下载 -${1}${2}-"
    ${WGET} -O "${BASE_DIR}/${1}${2}" "${BASE_URL}/${1}" 
    local result=$?
    [ "0" != "${result}" ] && rm -rf "${BASE_DIR}/${1}${2}"
    return ${result}
}


# 准备文件
ready() {

    echo "--------准备 ..."

    for file_name in ${ready_file}
    do
        dl "${file_name}" ".tmp" 
    done

    # installer/generic.sh
    sed -i 's_http://bin.entware.net_http://127.0.0.1_g' "${BASE_DIR}/installer/generic.sh.tmp"
    mv "${BASE_DIR}/installer/generic.sh.tmp" "${BASE_DIR}/installer/generic.sh"
    #cat "${BASE_DIR}/installer/generic.sh"

    # installer/opkg
    mv "${BASE_DIR}/installer/opkg.tmp" "${BASE_DIR}/installer/opkg"

    # installer/opkg.conf
    sed -i 's_^src/gz entware http://bin.entware.net_#src/gz entware http://bin.entware.net_' "${BASE_DIR}/installer/opkg.conf.tmp"
    sed -i '1isrc/gz local http://127.0.0.1/mipselsf-k3.4' "${BASE_DIR}/installer/opkg.conf.tmp"
    mv "${BASE_DIR}/installer/opkg.conf.tmp" "${BASE_DIR}/installer/opkg.conf"
    #cat "${BASE_DIR}/installer/opkg.conf"

    # Packages.gz
    [ -f "${PACKAGES}.gz.tmp" ] && {
        gzip -c -d "${PACKAGES}.gz.tmp" > "${PACKAGES}.tmp"
        rm -rf "${PACKAGES}.gz.tmp"
    }

    # installer/offline-mipsel-installer.tar.gz
    [ ${ARCH} = 'mipselsf-k3.4' ] && dl installer/offline-mipsel-installer.tar.gz

    # installer/offline-mips-installer.tar.gz
    [ ${ARCH} = 'mipssf-k3.4' ] && dl installer/offline-mips-installer.tar.gz
}


# list 生成，根据输入的软件包清单，搜索Packages文件，获取depends
# 1. 软件包清单
#
# sed 参数说明
# :a 跳转标签
# /^Depends:/p 打印 Depends 行信息
# n 读取下一行
# /^$/!b a 非空行跳转到 :a
list_generate_func() {

    [ -n "$1" ] && {

        let n+=1
        echo "--------list $n"
        #echo "$1"
        echo "$1" >> ${PACKAGES}.txt
        local tmp_list=""

        for pkg_name in $1 
        do 
            local depends="$(sed -n "/^Package:\ ${pkg_name}$/{:a;/^Depends:/p;n;/^$/!b a;}" ${PACKAGES}.tmp)"
            [ -n "${depends}" ] && {
                tmp_list="${tmp_list} $(echo "${depends#Depends:}" | sed "s/,/\ /g" )"
            }
        done 

        tmp_list="$(echo "${tmp_list}" | xargs -n1 | sort -u)"
        list_generate_func "${tmp_list}"
    }
}

list_generate() {

    echo "--------生成 list ..."
    rm -rf ${PACKAGES}.txt
    list_generate_func "$(cat entware.txt | xargs -n1 | sort -u)"
    sort -u -o${PACKAGES}.txt ${PACKAGES}.txt
}


# packages 生成 
packages_generate() {

    # packages 
    echo "--------生成 Packages ..."
    rm -rf "${PACKAGES}"
    for pkg_name in $(cat ${PACKAGES}.txt)
    do 
        #echo -${pkg_name}-
        sed -n "/^Package:\ ${pkg_name}$/{:a;p;n;/^$/!b a;}" ${PACKAGES}.tmp >> ${PACKAGES}
        echo >> ${PACKAGES}
    done 

    # packages.gz 
    echo "--------生成 Packages.gz ..."
    gzip -c ${PACKAGES} > ${PACKAGES}.gz
}


# 1. packages 下载
packages_download() {

    for pkg_file in $(sed -n "/^Filename:\ /{s/Filename:\ //g;p}" ${PACKAGES})
    do 
        dl "${pkg_file}"
    done 
}


# 帮助
usage="usage: ${0##*/} "
usage=${usage}'[all|ready|list|packages|download] '
usage=${usage}'[mipsel|mips|arm64|x64|x86] '


case $1 in 
    ready)    ready ;;
    list)     list_generate ;;
    packages) packages_generate ;;
    download) packages_download ;;
    all)      ready; list_generate; packages_generate; packages_download ;;
    *) echo "${usage}"
esac

