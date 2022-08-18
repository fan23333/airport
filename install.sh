#!/bin/bash


echo "检查运行环境"
if [ `whoami` != "root" ]; then
   echo "脚本停止：需以root身份运行本脚本（sudo bash install.sh）"
   exit 1
fi
if [[ $(lsof -i:80|grep -v 'PID' |grep 'LISTEN' | awk '{print $2}') != "" ]]; then
    if [ "$(command -v docker-compose)" ]; then
        echo "80端口被占用，尝试关闭删除当前目录下docker-compose"
        docker-compose rm -fs
        if [[ $(lsof -i:80|grep -v 'PID' |grep 'LISTEN' | awk '{print $2}') != "" ]]; then
            echo "脚本停止：80端口被占用，请取消占用"
            exit 1
        fi
    else
        echo "脚本停止：80端口被占用，请取消占用"
        exit 1
    fi
fi
if [[ $(lsof -i:443|grep -v 'PID' |grep 'LISTEN' | awk '{print $2}') != "" ]]; then
   echo "脚本停止：443端口被占用，请取消占用"
   exit 1
fi
if [[ $(lsof -i:54321|grep -v 'PID' |grep 'LISTEN' | awk '{print $2}') != "" ]]; then
   echo "脚本停止：54321端口被占用，请取消占用"
   exit 1
fi
# 检测wget命令
if [ ! "$(command -v wget)" ]; then
   echo "脚本停止：未检测到wget命令，请手动安装"
   exit 1
fi
# 检测curl命令
if [ ! "$(command -v curl)" ]; then
   echo "脚本停止：未检测到curl命令，请手动安装"
   exit 1
fi


# # 载入配置文件
# CFG_FILE=./config.ini

# email=` awk '$1~/\[.*/{_cdr_par_=0}\
#          $0 ~ /^ *\[ *config *\]/ {_cdr_par_=1}\
#          $0~/^[\011 ]*email *=.*/ { if(_cdr_par_==1) { sub("="," "); print $2; exit 0} }\
#          ' ${CFG_FILE}`

# domain=` awk '$1~/\[.*/{_cdr_par_=0}\
#           $0 ~ /^ *\[ *config *\]/ {_cdr_par_=1}\
#          $0~/^[\011 ]*domain *=.*/ { if(_cdr_par_==1) { sub("="," "); print $2; exit 0} }\
#          ' ${CFG_FILE}`

# disguise=` awk '$1~/\[.*/{_cdr_par_=0}\
#           $0 ~ /^ *\[ *config *\]/ {_cdr_par_=1}\
#          $0~/^[\011 ]*disguise *=.*/ { if(_cdr_par_==1) { sub("="," "); print $2; exit 0} }\
#          ' ${CFG_FILE}`

clear
echo "输入基本信息"
read -p "在此键入申请证书用的邮箱（如123@123.com）：" email 
read -p "在此键入拟使用的域名，勿使用顶级域名。记得做好DNS解析（如airport.domain.com）：" domain 
read -p '在此键入拟使用的伪装站点（仅输入域名，如www.baidu.com）：' disguise 

clear

usrCheck(){
    until [ "$confirm" = "y" ]
    do
        echo "输入y以继续，输入n以停止脚本"
        read  confirm  
        if [ "$confirm"  = "n" ];then
            echo "脚本停止"
            exit 1
        fi
    done
}

echo "请再次确认："
echo "邮箱：    $email " 
echo "域名：    $domain " 
echo "伪装站点：$disguise " 
usrCheck




echo "切换阻塞算法为BBR"
if [[ "$(echo $(sysctl net.ipv4.tcp_congestion_control) | grep "bbr")" == "" ]]; then
    echo "设置阻塞模式为BBR";
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo "切换成功"
fi


echo "检测docker"
if [ ! "$(command -v docker)" ]; then
    echo "未检测到docker，安装中。。。"
    sudo wget -qO- https://get.docker.com/ | sh
fi

echo "检测docker-compose"
if [ ! "$(command -v docker-compose)" ]; then
    echo "未检测到docker-compose，安装中。。。"
    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi



echo "下载文件"
sudo mkdir -p nginx www

curl -L "https://raw.githubusercontent.com/fan23333/airport/main/docker-compose.yaml" -o ./docker-compose.yaml
curl -L "https://raw.githubusercontent.com/fan23333/airport/main/www/index.html" -o ./www/index.html
curl -L "https://raw.githubusercontent.com/fan23333/airport/main/nginx/nginx.conf" -o ./nginx/nginx.conf
curl -L "https://raw.githubusercontent.com/fan23333/airport/main/nginx/nginx.conf.backup" -o ./nginx/nginx.conf.backup
curl -L "https://raw.githubusercontent.com/fan23333/airport/main/nginx/nginx.conf.demo" -o ./nginx/nginx.conf.demo


echo "启动docker"
sudo docker-compose up -d
echo "等待nginx启动"
sleep 10s 
clear

echo "端口检测"
echo "现在可以访问$domain了"
echo "如果一分钟后仍打不开，请确认已做好DNS解析，并且本机防火墙及主机服务商防火墙80、443、54321端口已开放"
echo "除非三个端口检测均为已开启，否则请勿进行下一步"
echo "测试网址：https://tool.chinaz.com/port，或者谷歌“端口检测”"

confirm=k
usrCheck

echo "申请证书"

sudo docker exec acme.sh --set-default-ca --server letsencrypt
sudo docker exec acme.sh --register-account  -m $email --server letsencrypt
sudo docker exec acme.sh --issue -d $domain -k ec-256 --webroot  /www
sudo docker exec acme.sh --install-cert -d $domain --ecc --key-file /cert/server.key --fullchain-file /cert/server.crt


echo "修改配置文件"
sudo cp -f ./nginx/nginx.conf.demo ./nginx/nginx.conf
sudo sed -i 's/airport.domain.com/'$domain'/g' ./nginx/nginx.conf
sudo sed -i 's/bing.com/'$disguise'/g' ./nginx/nginx.conf

clear

echo "现在可以访问X-UI面板了"
echo "网址：http://$domain:54321"
echo "用户名：admin"
echo "密码：  admin"
confirm=k
usrCheck

clear


echo "下面开始指引您配置X-UI面板"
echo "1.在系统状态->xray状态，将xray切换为最新版本"
confirm=k
usrCheck


clear

echo "2.入站列表->点击+添加节点"
echo "  备注：随意"
echo "  协议：vmess"
echo "  监听IP：0.0.0.0或不填写"
echo "  端口：随意设置1000-60000之间的数字"
port=10000
read -p "  在此键入您刚刚设置的端口:" port 
sudo sed -i 's/http:\/\/x-ui:10000/http:\/\/x-ui:'$port'/g' ./nginx/nginx.conf
echo "  继续设置传输：ws"
echo "  复制id"
id=ray
read -p "  在此粘贴id:" id 
sudo sed -i 's/location \/ray/location \/'$id'/g' ./nginx/nginx.conf
echo "  同时直接粘贴到面板的路径（不要删除路径中原来的'/'）"
echo "  点击添加"
confirm=k
usrCheck

clear

echo "3.面板设置"
echo "  不要修改监听IP"
echo "  设置一个面板url路径，此路径不应该过于简单，防止防火墙侦测，也不可设置成与id完全一样"
read -p "  在此粘贴路径（前后均不带'/'）:" xui
sudo sed -i 's/location \/xui/location \/'$xui'/g' ./nginx/nginx.conf
echo "  保存配置并重启面板"
confirm=k
usrCheck


clear


echo "重启nginx中请等待"
sudo docker restart nginx 
echo "nginx重启完毕"
echo "请检查https://$domain/是否为正常站点"
confirm=k
usrCheck

clear

echo "请通过https://$domain:$xui/访问面板"
echo "入站列表->查看，复制链接，导入到客户端"
confirm=k
usrCheck

clear

echo "以下操作在v2rayN等客户端中进行："
echo "1.修改节点端口为443"
echo "2.修改加密方式为zero（优先）或者none"
echo "3.传输层安全设置TLS"
confirm=k
usrCheck

clear

echo "本向导已完成，感谢您使用"
echo "跑到已清空，允许起飞"
echo "runway clear, allow to take off"
