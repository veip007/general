#!/bin/bash
Green_font="\033[32m" && Yellow_font="\033[33m" && Red_font="\033[31m" && Font_suffix="\033[0m"
Info="${Green_font}[Info]${Font_suffix}"
Error="${Red_font}[Error]${Font_suffix}"
reboot="${Yellow_font}重启${Font_suffix}"
echo -e "${Green_font}
#================================================
# Project:  tcp_nanqinlang general
# Platform: --Debian --KVM
# Branch:   --pro --with-kernel-v4.16-support
# Version:  3.4.5.1
# Author:   nanqinlang
# Blog:     https://sometimesnaive.org
# Github:   https://github.com/nanqinlang 
#================================================
${Font_suffix}"

check_system(){
	#cat /etc/issue | grep -q -E -i "debian" && release="debian"
	#[[ "${release}" != "debian" ]] && echo -e "${Error} only support Debian !" && exit 1
	[[ -z "`cat /etc/issue | grep -iE "debian"`" ]] && echo -e "${Error} only support Debian !" && exit 1
}

check_root(){
	[[ "`id -u`" != "0" ]] && echo -e "${Error} must be root user !" && exit 1
}

check_kvm(){
	apt-get update
	apt-get install -y virt-what
	apt-get install -y ca-certificates
	#virt=`virt-what`
	#[[ "${virt}" = "openvz" ]] && echo -e "${Error} OpenVZ not support !" && exit 1
	[[ "`virt-what`" != "kvm" ]] && echo -e "${Error} only support KVM !" && exit 1
}

directory(){
	[[ ! -d /home/tcp_nanqinlang ]] && mkdir -p /home/tcp_nanqinlang
	cd /home/tcp_nanqinlang
}

get_version(){
	echo -e "${Info} 输入你想要的内核版本号(仅支持版本号: 4.9.3 ~ 4.16.3):"
	read -p "(输入版本号，例如: 4.10.10，默认安装 v4.10.10):" required_version
	[[ -z "${required_version}" ]] && required_version=4.10.10
}

get_url(){
	get_version
	headers_all_name=`wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/ | grep "linux-headers" | awk -F'\">' '/all.deb/{print $2}' | cut -d'<' -f1 | head -1`
	headers_all_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/${headers_all_name}"
	bit=`uname -m`
	if [[ "${bit}" = "x86_64" ]]; then
		image_name=`wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/ | grep "linux-image" | grep "lowlatency" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1`
		image_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/${image_name}"
		headers_bit_name=`wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/ | grep "linux-headers" | grep "lowlatency" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1`
		headers_bit_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/${headers_bit_name}"
	elif [[ "${bit}" = "i386" ]]; then
		image_name=`wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/ | grep "linux-image" | grep "lowlatency" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1`
		image_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/${image_name}"
		headers_bit_name=`wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/ | grep "linux-headers" | grep "lowlatency" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1`
		headers_bit_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${required_version}/${headers_bit_name}"
	else
		echo -e "${Error} not support bit !" && exit 1
	fi
}

libssl(){
# for Kernel Headers
	echo -e "\ndeb http://ftp.us.debian.org/debian jessie main\c" >> /etc/apt/sources.list
	apt-get update && apt-get install -y libssl1.0.0
	sed  -i '/deb http:\/\/ftp\.us\.debian\.org\/debian jessie main/d' /etc/apt/sources.list
	#mv /etc/apt/sources.list /etc/apt/sources.list.backup
	#echo -e "\ndeb http://cdn-fastly.deb.debian.org/ jessie main\c" > /etc/apt/sources.list
	#apt-get update && apt-get install -y libssl1.0.0
	#sed  -i '/deb http:\/\/cdn-fastly\.deb\.debian\.org\/ jessie main/d' /etc/apt/sources.list
	#mv -f /etc/apt/sources.list.backup /etc/apt/sources.list
	apt-get update
}

libelf(){
# for Kernel v4.14
	[[ ! -z `echo ${required_version} | grep "4.14"` ]] && apt-get install -y libelf1
	[[ ! -z `echo ${required_version} | grep "4.15"` ]] && apt-get install -y libelf1
	[[ ! -z `echo ${required_version} | grep "4.16"` ]] && apt-get install -y libelf1
	[[ ! -z `uname -a | grep "4.14"` ]] && apt-get install -y libelf-dev
	[[ ! -z `uname -a | grep "4.15"` ]] && apt-get install -y libelf-dev
	[[ ! -z `uname -a | grep "4.16"` ]] && apt-get install -y libelf-dev
}

gcc4.9(){
# for Debian 7
	#sys_ver=`grep -oE  "[0-9.]+" /etc/issue`
	if [[ "`grep -oE  "[0-9.]+" /etc/issue`" = "7" ]]; then
		mv /etc/apt/sources.list /etc/apt/sources.list.backup
		wget https://raw.githubusercontent.com/nanqinlang/sources.list/master/hk.sources.list && mv hk.sources.list /etc/apt/sources.list
		apt-get update && apt-get install -y build-essential
		mv -f /etc/apt/sources.list.backup /etc/apt/sources.list
		apt-get update
	else
		apt-get install -y build-essential
	fi
}

delete_surplus_image(){
	for((integer = 1; integer <= ${surplus_total_image}; integer++))
	do
		 surplus_sort_image=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${required_version}" | head -${integer}`
		 apt-get purge -y ${surplus_sort_image}
	done
	apt-get autoremove -y
	if [[ "${surplus_total_image}" = "0" ]]; then
		 echo -e "${Info} uninstall all surplus images successfully, continuing"
	fi
}

delete_surplus_headers(){
	for((integer = 1; integer <= ${surplus_total_headers}; integer++))
	do
		 surplus_sort_headers=`dpkg -l|grep linux-headers | awk '{print $2}' | grep -v "${required_version}" | head -${integer}`
		 apt-get purge -y ${surplus_sort_headers}
	done
	apt-get autoremove -y
	if [[ "${surplus_total_headers}" = "0" ]]; then
		 echo -e "${Info} uninstall all surplus headers successfully, continuing"
	fi
}

install_image(){
	if [[ -f "${image_name}" ]]; then
		 echo -e "${Info} deb file exist"
	else echo -e "${Info} downloading image" && wget ${image_url}
	fi
	if [[ -f "${image_name}" ]]; then
		 echo -e "${Info} installing image" && dpkg -i ${image_name}
	else echo -e "${Error} image download failed, please check !" && exit 1
	fi
}

install_headers(){
	if [[ -f ${headers_all_name} ]]; then
		 echo -e "${Info} deb file exist"
	else echo -e "${Info} downloading headers_all" && wget ${headers_all_url}
	fi
	if [[ -f ${headers_all_name} ]]; then
		 echo -e "${Info} installing headers_all" && dpkg -i ${headers_all_name}
	else echo -e "${Error} headers_all download failed, please check !" && exit 1
	fi

	if [[ -f ${headers_bit_name} ]]; then
		 echo -e "${Info} deb file exist"
	else echo -e "${Info} downloading headers_bit" && wget ${headers_bit_url}
	fi
	if [[ -f ${headers_bit_name} ]]; then
		 echo -e "${Info} installing headers_bit" && dpkg -i ${headers_bit_name}
	else echo -e "${Error} headers_bit download failed, please check !" && exit 1
	fi
}

#check/install required version and remove surplus kernel
check_kernel(){
	get_url

	#when kernel version = required version, response required version number.
	digit_ver_image=`dpkg -l | grep linux-image | awk '{print $2}' | awk -F '-' '{print $3}' | grep "${required_version}"`
	digit_ver_headers=`dpkg -l | grep linux-headers | awk '{print $2}' | awk -F '-' '{print $3}' | grep "${required_version}"`

	#total digit of kernel without required version
	surplus_total_image=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${required_version}" | wc -l`
	surplus_total_headers=`dpkg -l|grep linux-headers | awk '{print $2}' | grep -v "${required_version}" | wc -l`

	if [[ -z "${digit_ver_image}" ]]; then
		 echo -e "${Info} installing required image" && install_image
	else echo -e "${Info} image already installed a required version"
	fi

	if [[ "${surplus_total_image}" != "0" ]]; then
		 echo -e "${Info} removing surplus image" && delete_surplus_image
	else echo -e "${Info} no surplus image need to remove"
	fi

	if [[ "${surplus_total_headers}" != "0" ]]; then
		 echo -e "${Info} removing surplus headers" && delete_surplus_headers
	else echo -e "${Info} no surplus headers need to remove"
	fi

	if [[ -z "${digit_ver_headers}" ]]; then
		 echo -e "${Info} installing required headers" && install_headers
	else echo -e "${Info} headers already installed a required version"
	fi

	update-grub
}

dpkg_list(){
	echo -e "${Info} 这是当前已安装的所有内核的列表："
    dpkg -l | grep linux-image   | awk '{print $2}'
    dpkg -l | grep linux-headers | awk '{print $2}'
	echo -e "${Info} 这是需要安装的所有内核的列表：\nlinux-image-${required_version}-lowlatency\nlinux-headers-${required_version}\nlinux-headers-${required_version}-lowlatency"
	echo -e "${Info} 请确保上下两个列表一致！"
}

ver_current(){
	[[ ! -f /lib/modules/`uname -r`/kernel/net/ipv4/tcp_nanqinlang.ko ]] && compiler
	[[ ! -f /lib/modules/`uname -r`/kernel/net/ipv4/tcp_nanqinlang.ko ]] && echo -e "${Error} load mod failed, please check !" && exit 1
}
compiler(){
	#mkdir make && cd make

	# kernel source code：https://www.kernel.org/pub/linux/kernel
	# kernel v4.13.x is different from the other older kernel
	ver_4_13=`dpkg -l | grep linux-image | awk '{print $2}' | awk -F '-' '{print $3}' | grep "4.13"`
	ver_4_14=`dpkg -l | grep linux-image | awk '{print $2}' | awk -F '-' '{print $3}' | grep "4.14"`
	ver_4_15=`dpkg -l | grep linux-image | awk '{print $2}' | awk -F '-' '{print $3}' | grep "4.15"`
	ver_4_16=`dpkg -l | grep linux-image | awk '{print $2}' | awk -F '-' '{print $3}' | grep "4.16"`
	if   [[ ! -z "${ver_4_16}" ]]; then
		wget https://raw.githubusercontent.com/veip007/general/master/General/Debian/source/kernel-v4.16/tcp_nanqinlang.c
	elif [[ ! -z "${ver_4_15}" ]]; then
		wget https://raw.githubusercontent.com/veip007/general/master/General/Debian/source/kernel-v4.15/tcp_nanqinlang.c
	elif [[ ! -z "${ver_4_14}" ]]; then
		wget https://raw.githubusercontent.com/veip007/general/master/General/Debian/source/kernel-v4.14/tcp_nanqinlang.c
	elif [[ ! -z "${ver_4_13}" ]]; then
		wget https://raw.githubusercontent.com/veip007/general/master/General/Debian/source/kernel-v4.13/tcp_nanqinlang.c
	else
		wget https://raw.githubusercontent.com/veip007/general/master/General/Debian/source/kernel-v4.12andbelow/tcp_nanqinlang.c
	fi

	[[ ! -f tcp_nanqinlang.c ]] && echo -e "${Error} failed download tcp_nanqinlang.c, please check !" && exit 1

	#sys_ver=`grep -oE  "[0-9.]+" /etc/issue`
	if [[ "`grep -oE  "[0-9.]+" /etc/issue`" = "9" ]]; then
		wget -O Makefile https://raw.githubusercontent.com/veip007/general/master/Makefile/Makefile-Debian9
	else
		wget -O Makefile https://raw.githubusercontent.com/veip007/general/master/Makefile/Makefile-Debian7or8
	fi

	[[ ! -f Makefile ]] && echo -e "${Error} failed download Makefile, please check !" && exit 1

	make && make install
}

check_status(){
	#status_sysctl=`sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'`
	#status_lsmod=`lsmod | grep nanqinlang`
	if [[ "`lsmod | grep nanqinlang`" != "" ]]; then
		echo -e "${Info} tcp_nanqinlang is installed !"
			if [[ "`sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'`" = "nanqinlang" ]]; then
				 echo -e "${Info} tcp_nanqinlang is running !"
			else echo -e "${Error} tcp_nanqinlang is installed but not running !"
			fi
	else
		echo -e "${Error} tcp_nanqinlang not installed !"
	fi
}



###################################################################################################
install(){
	check_system
	check_root
	check_kvm
	directory
	gcc4.9
	libssl
	libelf
	check_kernel
	dpkg_list
	echo -e "${Info} 确认内核安装无误后, ${reboot}你的VPS, 开机后再次运行该脚本的第二项！"
}

start(){
	check_system
	check_root
	check_kvm
	directory
	ver_current
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	echo -e "\nnet.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo -e "net.ipv4.tcp_congestion_control=nanqinlang\c" >> /etc/sysctl.conf
	sysctl -p
	check_status
	rm -rf /home/tcp_nanqinlang
}

status(){
	check_status
}

uninstall(){
	check_root
	sed -i '/net\.core\.default_qdisc=/d'          /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control=/d' /etc/sysctl.conf
	sysctl -p
	rm  /lib/modules/`uname -r`/kernel/net/ipv4/tcp_nanqinlang.ko
	echo -e "${Info} please remember ${reboot} to stop tcp_nanqinlang !"
}

echo -e "${Info} 选择你要使用的功能: "
echo -e "1.安装内核\n2.安装并开启算法\n3.检查算法运行状态\n4.卸载算法"
read -p "输入数字以选择:" function

while [[ ! "${function}" =~ ^[1-4]$ ]]
	do
		echo -e "${Error} 无效输入"
		echo -e "${Info} 请重新选择" && read -p "输入数字以选择:" function
	done

if   [[ "${function}" == "1" ]]; then
	install
elif [[ "${function}" == "2" ]]; then
	start
elif [[ "${function}" == "3" ]]; then
	status
else
	uninstall
fi
