#!/bin/bash
#
# Lisence: MIT
#
# File name: part.sh
#
# Description: DIY Script Part
#

echo "开始 DIY 配置..."
echo "===================="

function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 允许root编译
# export FORCE_UNSAFE_CONFIGURE=1

# 修改默认IP
sed -i 's/192.168.1.1/192.168.2.100/g' package/base-files/files/bin/config_generate

# 更改Shell
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 拉取软件包
git_sparse_clone main https://github.com/cnfind/v luci-app-adguardhome
git_sparse_clone main https://github.com/cnfind/v luci-app-eqosplus
rm -rf feeds/luci/applications/luci-app-netdata
git_sparse_clone main https://github.com/cnfind/v luci-app-netdata

# OpenClash
git_sparse_clone main https://github.com/cnfind/v luci-app-openclash
# AndPo2lmo
pushd package/luci-app-openclash/tools/po2lmo
make && sudo make install
popd

# Alist
# git_sparse_clone master https://github.com/sbwml/luci-app-alist alist
# git_sparse_clone master https://github.com/sbwml/luci-app-alist luci-app-alist

# MosDNS
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
git_sparse_clone main https://github.com/cnfind/v luci-app-mosdns/mosdns
git_sparse_clone main https://github.com/cnfind/v luci-app-mosdns/luci-app-mosdns

# Onliner
git_sparse_clone main https://github.com/cnfind/v luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=10s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings

# Amlogic
# git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
# sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/cnfind/z'|g" package/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|firmware_tag.*|firmware_tag 'N1'|g" package/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/cnfind/z'|g" package/luci-app-amlogic/root/etc/config/amlogic

# Themes
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
git_sparse_clone main https://github.com/cnfind/v luci-theme-argon
git_sparse_clone main https://github.com/cnfind/v luci-app-argon-config
git_sparse_clone main https://github.com/cnfind/v luci-theme-edge
git_sparse_clone main https://github.com/cnfind/v luci-theme-ifit

# 更改主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 取消主题设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 修改默认主题
# sed -i 's/luci-theme-bootstrap/luci-theme-ifit/g' feeds/luci/collections/luci/Makefile

# 修改时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改主机名称
sed -i "s/hostname='OpenWrt'/hostname='OpenN1'/g" package/base-files/files/bin/config_generate

# 移除跑分信息
# sed -i "s|\ <%=luci.sys.exec(\"cat \/etc\/bench.log\") or \" \"%>||g" feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm

# 修改版本日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by CnFind/g" package/lean/default-settings/files/zzz-default-settings

# Docker>服务
# sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/dockerman.lua
# sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
# sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
# sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm

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

./scripts/feeds update -a
./scripts/feeds install -a

echo "===================="
echo "结束 DIY 配置..."
