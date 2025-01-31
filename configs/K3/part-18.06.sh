#!/bin/bash
#
# File name: part-18.06.sh
#
# Description: DIY Script Part
#

echo "开始 DIY 配置..."
echo "===================="

# 打包Toolchain
if [[ $REBUILD_TOOLCHAIN = 'true' ]]; then
    echo -e "\e[1;33m开始打包toolchain目录\e[0m"
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    [ -d ".ccache" ] && (ccache=".ccache"; ls -alh .ccache)
    du -h --max-depth=1 ./staging_dir
    du -h --max-depth=1 ./ --exclude=staging_dir
    tar -I zstdmt -cf $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst staging_dir/host* staging_dir/tool* $ccache
    ls -lh $GITHUB_WORKSPACE/output
    [ -e $GITHUB_WORKSPACE/output/$CACHE_NAME.tzst ] || exit 1
    exit 0
fi

[ -d $GITHUB_WORKSPACE/output ] || mkdir $GITHUB_WORKSPACE/output

color() {
    case $1 in
        cr) echo -e "\e[1;31m$2\e[0m" ;;
        cg) echo -e "\e[1;32m$2\e[0m" ;;
        cy) echo -e "\e[1;33m$2\e[0m" ;;
        cb) echo -e "\e[1;34m$2\e[0m" ;;
        cp) echo -e "\e[1;35m$2\e[0m" ;;
        cc) echo -e "\e[1;36m$2\e[0m" ;;
    esac
}

status() {
    local check=$? end_time=$(date '+%H:%M:%S') total_time
    total_time="==> 用时 $[$(date +%s -d $end_time) - $(date +%s -d $begin_time)] 秒"
    [[ $total_time =~ [0-9]+ ]] || total_time=""
    if [[ $check = 0 ]]; then
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cg ✔) ] $(echo -e "\e[1m$total_time")
    else
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cr ✕) ] $(echo -e "\e[1m$total_time")
    fi
}

find_dir() {
    find $1 -maxdepth 3 -type d -name $2 -print -quit 2>/dev/null
}

print_info() {
    printf "%s %-40s %s %s %s\n" $1 $2 $3 $4 $5
    # read -r param1 param2 param3 param4 param5 <<< $1
    # printf "%s %-40s %s %s %s\n" $param1 $param2 $param3 $param4 $param5
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    if [[ -n "$@" ]]; then
        target_dir="$@"
    else
        target_dir="${repo_url##*/}"
    fi
    git clone -q $branch --depth=1 $repo_url $target_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if ([[ -d $current_dir ]] && rm -rf $current_dir); then
        mv -f $target_dir ${current_dir%/*}
        print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
    else
        mv -f $target_dir $destination_dir
        print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d $source_dir ]] || \
        source_dir=$(find $temp_dir -maxdepth 4 -type d -name $target_dir -print -quit) && \
        [[ -d $source_dir ]] || {
            print_info $(color cr 查找) $target_dir [ $(color cr ✕) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 添加源仓库内的所有目录
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in $(ls -l $temp_dir/$@ | awk '/^d/{print $NF}'); do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 设置编译源码与分支
REPO_URL="https://github.com/coolsnowwolf/lede"
echo "REPO_URL=$REPO_URL" >>$GITHUB_ENV
REPO_BRANCH="master"
echo "REPO_BRANCH=$REPO_BRANCH" >>$GITHUB_ENV

# 开始拉取编译源码
begin_time=$(date '+%H:%M:%S')
[[ $REPO_BRANCH != "master" ]] && BRANCH="-b $REPO_BRANCH --single-branch"
cd /workdir
git clone -q $BRANCH $REPO_URL openwrt
status "拉取编译源码"
ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt
[ -d openwrt ] && cd openwrt || exit
echo "OPENWRT_PATH=$PWD" >>$GITHUB_ENV

# 设置luci版本为18.06
sed -i '/luci/s/^#//; /openwrt-23.05/s/^/#/' feeds.conf.default

# 开始生成全局变量
begin_time=$(date '+%H:%M:%S')
[ -e $GITHUB_WORKSPACE/$CONFIG_FILE ] && cp -f $GITHUB_WORKSPACE/$CONFIG_FILE .config
make defconfig 1>/dev/null 2>&1

# 源仓库与分支
SOURCE_REPO=$(basename $REPO_URL)
echo "SOURCE_REPO=$SOURCE_REPO" >>$GITHUB_ENV
echo "LITE_BRANCH=${REPO_BRANCH#*-}" >>$GITHUB_ENV

# 平台架构
TARGET_NAME=$(awk -F '"' '/CONFIG_TARGET_BOARD/{print $2}' .config)
SUBTARGET_NAME=$(awk -F '"' '/CONFIG_TARGET_SUBTARGET/{print $2}' .config)
DEVICE_TARGET=$TARGET_NAME-$SUBTARGET_NAME
echo "DEVICE_TARGET=$DEVICE_TARGET" >>$GITHUB_ENV

# 内核版本
KERNEL=$(grep -oP 'KERNEL_PATCHVER:=\K[^ ]+' target/linux/$TARGET_NAME/Makefile)
KERNEL_VERSION=$(awk -F '-' '/KERNEL/{print $2}' include/kernel-$KERNEL | awk '{print $1}')
echo "KERNEL_VERSION=$KERNEL_VERSION" >>$GITHUB_ENV

# Toolchain缓存文件名
TOOLS_HASH=$(git log --pretty=tformat:"%h" -n1 tools toolchain)
CACHE_NAME="$SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-cache-$TOOLS_HASH"
echo "CACHE_NAME=$CACHE_NAME" >>$GITHUB_ENV

# 源码更新信息
COMMIT_AUTHOR=$(git show -s --date=short --format="作者: %an")
echo "COMMIT_AUTHOR=$COMMIT_AUTHOR" >>$GITHUB_ENV
COMMIT_DATE=$(git show -s --date=short --format="时间: %ci")
echo "COMMIT_DATE=$COMMIT_DATE" >>$GITHUB_ENV
COMMIT_MESSAGE=$(git show -s --date=short --format="内容: %s")
echo "COMMIT_MESSAGE=$COMMIT_MESSAGE" >>$GITHUB_ENV
COMMIT_HASH=$(git show -s --date=short --format="hash: %H")
echo "COMMIT_HASH=$COMMIT_HASH" >>$GITHUB_ENV
status "生成全局变量"

# 下载并部署Toolchain
if [[ $TOOLCHAIN = 'true' ]]; then
    cache_xa=$(curl -sL api.github.com/repos/$GITHUB_REPOSITORY/releases | awk -F '"' '/download_url/{print $4}' | grep $CACHE_NAME)
    cache_xc=$(curl -sL api.github.com/repos/cnfind/toolchain-cache/releases | awk -F '"' '/download_url/{print $4}' | grep $CACHE_NAME)
    if [[ $cache_xa || $cache_xc ]]; then
        begin_time=$(date '+%H:%M:%S')
        [ $cache_xa ] && wget -qc -t=3 $cache_xa || wget -qc -t=3 $cache_xc
        [ -e *.tzst ]; status "下载toolchain缓存文件"
        [ -e *.tzst ] && {
            begin_time=$(date '+%H:%M:%S')
            tar -I unzstd -xf *.tzst || tar -xf *.tzst
            [ $cache_xa ] || (cp *.tzst $GITHUB_WORKSPACE/output && echo "OUTPUT_RELEASE=true" >>$GITHUB_ENV)
            sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
            [ -d staging_dir ]; status "部署toolchain编译缓存"
        }
    else
        echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
    fi
else
    echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
fi

# 开始更新&安装插件
begin_time=$(date '+%H:%M:%S')
./scripts/feeds update -a 1>/dev/null 2>&1
./scripts/feeds install -a 1>/dev/null 2>&1
status "更新&安装插件"

# 创建插件保存目录
destination_dir="package/A"
[ -d $destination_dir ] || mkdir -p $destination_dir

color cy "添加&替换插件"

# 替换屏幕驱动
rm -rf package/lean/luci-app-k3screenctrl
rm -rf package/lean/k3screenctrl
clone_dir main https://github.com/cnfind/v k3/luci-app-k3screenctrl
clone_dir main https://github.com/cnfind/v k3/k3screenctrl
clone_dir main https://github.com/cnfind/v k3/k3screenctrl_build

# 移除其他机型
sed -i '421,453d' target/linux/bcm53xx/image/Makefile
sed -i '140,412d' target/linux/bcm53xx/image/Makefile
sed -i 's/$(USB3_PACKAGES) k3screenctrl/luci-app-k3screenctrl/g' target/linux/bcm53xx/image/Makefile

# 替换无线驱动
firmware='69027'
wget -nv https://github.com/cnfind/v/raw/main/k3/wireless/brcmfmac4366c-pcie.bin.${firmware} -O package/lean/k3-firmware/files/brcmfmac4366c-pcie.bin

# 添加插件包
clone_dir main https://github.com/cnfind/v luci-app-adguardhome
clone_dir main https://github.com/cnfind/v luci-app-eqosplus
# rm -rf feeds/luci/applications/luci-app-netdata
clone_dir main https://github.com/cnfind/v luci-app-netdata

# OpenClash
clone_dir main https://github.com/cnfind/v luci-app-openclash
# AndPo2lmo
pushd $destination_dir/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

# Alist
# clone_dir master https://github.com/sbwml/luci-app-alist alist
# clone_dir master https://github.com/sbwml/luci-app-alist luci-app-alist

# MosDNS
# rm -rf feeds/packages/net/mosdns
# rm -rf feeds/luci/applications/luci-app-mosdns
clone_dir main https://github.com/cnfind/v luci-app-mosdns-lua

# Onliner
clone_dir main https://github.com/cnfind/v luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=10s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings

# Themes
# rm -rf feeds/luci/themes/luci-theme-argon
# rm -rf feeds/luci/applications/luci-app-argon-config
clone_dir main https://github.com/cnfind/v luci-theme-argon
clone_dir main https://github.com/cnfind/v luci-app-argon-config
clone_dir main https://github.com/cnfind/v luci-theme-edge
clone_dir main https://github.com/cnfind/v luci-theme-ifit

# 更改主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 开始加载个人设置
begin_time=$(date '+%H:%M:%S')

[ -e $GITHUB_WORKSPACE/K3/files-18.06/files ] && mv $GITHUB_WORKSPACE/K3/files-18.06/files files

# 设置固件rootfs大小
if [ $PART_SIZE ]; then
    sed -i '/ROOTFS_PARTSIZE/d' $GITHUB_WORKSPACE/$CONFIG_FILE
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$PART_SIZE" >>$GITHUB_WORKSPACE/$CONFIG_FILE
fi

# 修改默认IP
[ $DEFAULT_IP ] && sed -i '/n) ipad/s/".*"/"'"$DEFAULT_IP"'"/' package/base-files/files/bin/config_generate

# 更改Shell
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 取消主题设置
# find $destination_dir/luci-theme-*/ -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 修改默认主题
# sed -i 's/luci-theme-bootstrap/luci-theme-ifit/g' feeds/luci/collections/luci/Makefile

# 修改时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/arm/index.htm

# 修改主机名称
sed -i "s/hostname='OpenWrt'/hostname='OpenK3'/g" package/base-files/files/bin/config_generate

# 修改upnp位置
sed -i 's/\/var\/upnp.leases/\/tmp\/upnp.leases/g' feeds/packages/net/miniupnpd/files/upnpd.config

# 添加CPU温度
sed -i "/<tr><td width=\"33%\"><%:Load Average%>/a \ \t\t<tr><td width=\"33%\"><%:CPU Temperature%></td><td><%=luci.sys.exec(\"sed 's/../&./g' /sys/class/thermal/thermal_zone0/temp|cut -c1-4\")%></td></tr>" feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm

# 修改版本日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by CnFind/g" package/lean/default-settings/files/zzz-default-settings

# 调整插件排序
# sed -i 's/_("KMS Server"), 100/_("KMS Server"), 101/g' feeds/luci/applications/luci-app-vlmcsd/luasrc/controller/vlmcsd.lua

# 更改插件名字
sed -i 's/"TTYD 终端"/"TTYD"/g' `egrep "TTYD 终端" -rl ./`
sed -i 's/"Argon 主题设置"/"主题设置"/g' `egrep "Argon 主题设置" -rl ./`
sed -i 's/"KMS 服务器"/"KMS Server"/g' `egrep "KMS 服务器" -rl ./`
sed -i 's/"网络存储"/"存储"/g' `egrep "网络存储" -rl ./`
sed -i 's/"Turbo ACC 网络加速"/"网络加速"/g' `egrep "Turbo ACC 网络加速" -rl ./`
sed -i 's/"带宽监控"/"带宽"/g' `egrep "带宽监控" -rl ./`
sed -i 's/"网速监控"/"网速"/g' `egrep "网速监控" -rl ./`
sed -i 's/"实时流量监测"/"流量"/g' `egrep "实时流量监测" -rl ./`

# 修复 Makefile 路径
find $destination_dir/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i \
    -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?' \
    -e 's?include \.\./\.\./\(lang\|devel\)?include $(TOPDIR)/feeds/packages/\1?' {}

# 转换插件语言翻译
for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
    if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
        ln -s zh-cn $e/zh_Hans 2>/dev/null
    elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
        ln -s zh_Hans $e/zh-cn 2>/dev/null
    fi
done
status "加载个人设置"

# 开始下载openchash运行内核
[ $CLASH_KERNEL ] && {
    begin_time=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
    $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CLASH_KERNEL
    status "下载openchash运行内核"
}

# 开始下载zsh终端工具
[[ $ZSH_TOOL = 'true' ]] && {
    begin_time=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    status "下载zsh终端工具"
}

# 开始下载adguardhome运行内核
[ $CLASH_KERNEL ] && {
    begin_time=$(date '+%H:%M:%S')
    chmod +x $GITHUB_WORKSPACE/scripts/preset-adguard-core.sh
    $GITHUB_WORKSPACE/scripts/preset-adguard-core.sh $CLASH_KERNEL
    status "下载adguardhome运行内核"
}

# 开始更新配置文件
begin_time=$(date '+%H:%M:%S')
[ -e $GITHUB_WORKSPACE/$CONFIG_FILE ] && cp -f $GITHUB_WORKSPACE/$CONFIG_FILE .config
make defconfig 1>/dev/null 2>&1
status "更新配置文件"

echo -e "$(color cy 当前编译机型) $(color cb $SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-$KERNEL_VERSION)"

color cp "脚本运行完成！"

echo "===================="
echo "结束 DIY 配置..."