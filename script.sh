#!/bin/bash

set -e

if [[ ! -z "$SKIP_DEBUGGER" ]]; then
  echo "Skipping debugger because SKIP_DEBUGGER enviroment variable is set"
  exit
fi

# Install tmate on macOS or Ubuntu
echo Setting up tmate...
if [ -x "$(command -v brew)" ]; then
  brew install tmate > /tmp/brew.log
fi
if [ -x "$(command -v apt-get)" ]; then
  sudo apt-get install -y tmate openssh-client > /tmp/apt-get.log
fi

# Generate ssh key if needed
[ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo Running tmate...
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready

# Print connection info
echo ________________________________________________________________________________
echo ooook

cd
echo cd ok
sudo git clone https://github.com/TophantTechnology/ARL.git
echo clone ok
cd ARL/docker/
echo cd ok
sudo sed -i "s/#- \"5003:80\"/- \"5004:80\"/g" docker-compose.yml
sudo docker volume create --name=arl_db
sudo docker-compose up -d
echo up ok
cd
git clone https://github.com/open-dingtalk/pierced.git
cd pierced/linux
sudo nohup ./ding -config=./ding.cfg -subdomain=arltest 5004 &
echo up ok
echo ________________________________________________________________________________
echo
echo To connect to this session copy-n-paste the following into a terminal:
tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}'
echo After connecting you can run 'touch /tmp/keepalive' to disable the 15m timeout

if [[ ! -z "$SLACK_WEBHOOK_URL" ]]; then
  MSG=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
  curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"\`$MSG\`\"}" $SLACK_WEBHOOK_URL
fi




# Wait for connection to close or timeout in 15 min
timeout=$((1*60))
while [ -S /tmp/tmate.sock ]; do
  sleep 1
  timeout=$(($timeout-1))
  echo timeout

  if [ ! -f /tmp/keepalive ]; then
    if (( timeout < 0 )); then
      sudo kill -9 `cat /root/pid.txt`
      echo Waiting on tmate connection timed out!
      exit 1
    fi
  fi
done
