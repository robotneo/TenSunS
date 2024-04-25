#!/bin/bash
export PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
tsspath="/opt/tensuns"
uuid=`uuidgen`
adminpwd=`uuidgen|awk -F- '{print $1}'`
mkdir -p $tsspath/consul/config
cat <<EOF > $tsspath/consul/config/consul.hcl
log_level = "error"
data_dir = "/consul/data"
client_addr = "0.0.0.0"
ui_config{
  enabled = true
}
ports = {
  grpc = -1
  https = -1
  dns = -1
  grpc_tls = -1
  serf_wan = -1
}
peering {
  enabled = false
}
connect {
  enabled = false
}
server = true
bootstrap_expect=1
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    initial_management = "$uuid"
    agent = "$uuid"
  }
}
EOF
chmod 777 -R $tsspath/consul/config
cat <<EOF > $tsspath/compose.yaml
services:
  consul:
    image: swr.cn-south-1.myhuaweicloud.com/starsl.cn/consul:latest
    container_name: consul
    hostname: consul
    restart: always
    ports:
      - "8500:8500"
    volumes:
     - $tsspath/consul/data:/consul/data
     - $tsspath/consul/config:/consul/config
     - /usr/share/zoneinfo/PRC:/etc/localtime
    command: "agent"
    networks:
      - TenSunS

  flask-consul:
    image: swr.cn-south-1.myhuaweicloud.com/starsl.cn/flask-consul:latest
    container_name: flask-consul
    hostname: flask-consul
    restart: always
    volumes:
      - /usr/share/zoneinfo/PRC:/etc/localtime
    environment:
      consul_token: $uuid
      consul_url: http://consul:8500/v1
      admin_passwd: $adminpwd
      log_level: INFO
    depends_on:
      - consul
    networks:
      - TenSunS

  nginx-consul:
    image: swr.cn-south-1.myhuaweicloud.com/starsl.cn/nginx-consul:latest
    container_name: nginx-consul
    hostname: nginx-consul
    restart: always
    ports:
      - "1026:1026"
    volumes:
      - /usr/share/zoneinfo/PRC:/etc/localtime
    depends_on:
      - flask-consul
    networks:
      - TenSunS

networks:
  TenSunS:
    name: TenSunS
    driver: bridge
    ipam:
      driver: default
EOF

echo -e "\n\033[31;1m正在启动后羿运维平台...\033[0m"
cd $tsspath && docker compose -f compose.yaml -p tensuns up -d
echo -e "\n后羿运维平台默认的admin密码是：\033[31;1m$adminpwd\033[0m\n修改密码请编辑 $tsspath/compose.yaml 查找并修改变量 admin_passwd 的值\n"
echo -e "请使用浏览器访问 http://{你的IP}:1026 并登录使用\n"
echo -e "\033[31;1mhttp://`ip route get 1.2.3.4 | awk '/src/ { for(i=1;i<=NF;i++) if ($i=="src") print $(i+1) }'`:1026\033[0m\n"
