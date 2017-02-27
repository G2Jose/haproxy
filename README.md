# [http://georgejose.com](https://georgejose.com)

[![build status](http://ci.georgejose.com/api/v1/teams/main/pipelines/pipeline/jobs/deploy-haproxy/badge)](http://ci.georgejose.com/)

My HAProxy configuration for HTTPS.

## How to use

### Using Docker (Recommended)
- Install docker
- Clone repo
- Place your SSL certificate at `haproxy/private/`
- Run `docker build -t haproxy . && docker run -d --net=host -t haproxy` to build and run Docker container
