# [http://georgejose.com](https://georgejose.com)

[![build status](https://gitlab.com/G2Jose/personal_website/badges/master/build.svg)](https://gitlab.com/G2Jose/personal_website/commits/master)

My HAProxy configuration for HTTPS.

## How to use

### Using Docker (Recommended)
- Install docker
- Clone repo
- Place your SSL certificate at `haproxy/private/`
- Run `docker build -t haproxy . && docker run -d --net=host -t haproxy` to build and run Docker container
