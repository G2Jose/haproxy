#!/bin/sh
sanitize_cgroups() {
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  mount -o remount,rw /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<$sys\\>")"
    if [ -z "$grouping" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="$sys"
    fi

    mountpoint="/sys/fs/cgroup/$grouping"

    mkdir -p "$mountpoint"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "$mountpoint"

    if [ "$grouping" != "$sys" ]; then
      if [ -L "/sys/fs/cgroup/$sys" ]; then
        rm "/sys/fs/cgroup/$sys"
      fi

      ln -s "$mountpoint" "/sys/fs/cgroup/$sys"
    fi
  done
}

start_docker() {
  mkdir -p /var/log
  mkdir -p /var/run

  sanitize_cgroups

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  local mtu=$(cat /sys/class/net/$(ip route get 8.8.8.8|awk '{ print $5 }')/mtu)
  local server_args="--mtu ${mtu}"
  local registry=""

  for registry in $1; do
    server_args="${server_args} --insecure-registry ${registry}"
  done

  if [ -n "$2" ]; then
    server_args="${server_args} --registry-mirror=$2"
  fi

  docker daemon ${server_args} >/tmp/docker.log 2>&1 &
  echo $! > /tmp/docker.pid

  trap stop_docker EXIT

  sleep 1

  until docker info >/dev/null 2>&1; do
    echo waiting for docker to come up...
    sleep 1
  done
}
stop_docker() {
  local pid=$(cat /tmp/docker.pid)
  if [ -z "$pid" ]; then
    return 0
  fi

  kill -TERM $pid
  wait $pid
}
start_docker
apk add --no-cache openssh-client
eval $(ssh-agent -s)
echo "$DEPLOY_SSH_KEY" > ssh_key
chmod 400 ssh_key && ssh-add ssh_key && rm -rf ssh_key
mkdir -p ~/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config

ssh $SSH_HOST << EOF

  #Log in to docker hub
  docker login --username=$DOCKER_HUB_USERNAME --password=$DOCKER_HUB_PASSWORD
  docker pull $DOCKER_HUB_DEPLOY_TAG

  # Delete all stopped containers
  docker ps -q -f status=exited | xargs --no-run-if-empty docker rm
  # Delete all dangling (unused) images
  docker images -q -f dangling=true | xargs --no-run-if-empty docker rmi

  #stop and remove containers that have the image $DOCKER_HUB_DEPLOY_TAG as their ancestor
  # docker ps -a -q --filter ancestor=$DOCKER_HUB_DEPLOY_TAG --format={{.ID}} | xargs docker stop
  # docker ps -a -q --filter ancestor=$DOCKER_HUB_DEPLOY_TAG --format={{.ID}} | xargs docker rm
  
  docker stop "$DOCKER_HUB_DEPLOY_NAME"
  docker rm "$DOCKER_HUB_DEPLOY_NAME"

  #Start container from image $DOCKER_HUB_DEPLOY_TAG & exit success / failure
  docker run --net=host -d --restart always --name "$DOCKER_HUB_DEPLOY_NAME" "$DOCKER_HUB_DEPLOY_TAG"
  
  #Start container from image $DOCKER_HUB_DEPLOY_TAG & exit success / failure
  # docker run --net=host -d --name "$DOCKER_HUB_DEPLOY_NAME" "$DOCKER_HUB_DEPLOY_TAG"
EOF

exit $?
