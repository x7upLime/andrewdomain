FROM ubuntu:latest as STAGEONE

# install hugo
ENV HUGO_VERSION=0.109.0
ADD https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz /tmp/
RUN tar -xf /tmp/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin/

# install syntax highlighting
# RUN apt install python3-pygments -y

# build site
COPY ./ /source
RUN hugo --source=/source/ --destination=/public/

FROM nginx:stable-alpine
# RUN apk --update add curl bash iproute2 ## trash [!]
## replaces nginx's default.conf inside container
COPY ./andrewdomain-bloh.conf /etc/nginx/conf.d/default.conf
COPY --from=STAGEONE /public/ /usr/share/nginx/html
EXPOSE 80

LABEL andrewdomain "blog"
MAINTAINER andrew <andrew@andrewdomain.com>
## ideas stolen from https://luiscachog.io/blog-hugo-docker-k8s-quay/ :)
