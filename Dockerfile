
ARG IMAGE=registry.redhat.io/3scale-amp2/apicast-gateway-rhel8:3scale2.13

FROM ${IMAGE}

USER root
WORKDIR /opt/app-root/src/

RUN dnf install -y perl-App-cpanminus gcc git

RUN git config --global url.https://github.com/.insteadOf git://github.com/

ENV LUA_PATH="/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;"

COPY Roverfile .
COPY Roverfile.lock .

RUN rover install --roverfile=/opt/app-root/src/Roverfile

CMD /opt/app-root/src/bin/apicast
