FROM debian AS ideaDownloader

# prepare tools:
RUN apt-get update
RUN apt-get install wget -y
# download idea to the idea/ dir:
ENV IDEA_ARCHIVE_NAME ideaIC-2019.3.3.tar.gz
RUN wget -q https://download.jetbrains.com/idea/$IDEA_ARCHIVE_NAME -O - | tar -xz
RUN find . -maxdepth 1 -type d -name "idea-*" -execdir mv {} /idea \;

FROM debian AS projectorStaticFiles

# prepare tools:
RUN apt-get update
RUN apt-get install patch -y
# create the Projector dir:
ENV PROJECTOR_DIR /projector
RUN mkdir -p $PROJECTOR_DIR
# copy projector files to the container:
COPY to-container $PROJECTOR_DIR
# prepare index.html (TODO: this won't be needed after Kotlin/JS 1.3.70):
RUN patch $PROJECTOR_DIR/index.html < $PROJECTOR_DIR/index.html.patch
RUN rm $PROJECTOR_DIR/index.html.patch
# copy idea:
COPY --from=ideaDownloader /idea $PROJECTOR_DIR/idea
# prepare idea - apply projector-server:
RUN mv $PROJECTOR_DIR/projector-server-1.0-SNAPSHOT.jar $PROJECTOR_DIR/idea
RUN patch $PROJECTOR_DIR/idea/bin/idea.sh < $PROJECTOR_DIR/idea.sh.patch
RUN rm $PROJECTOR_DIR/idea.sh.patch

FROM nginx

# copy the Projector dir:
ENV PROJECTOR_DIR /projector
COPY --from=projectorStaticFiles $PROJECTOR_DIR $PROJECTOR_DIR

RUN true \
# Any command which returns non-zero exit code will cause this shell script to exit immediately:
    && set -e \
# Activate debugging to show execution details: all commands will be printed before execution
    && set -x \
# move run scipt:
    && mv $PROJECTOR_DIR/run.sh run.sh \
# prepare nginx:
    && mkdir -p /usr/share/nginx/html/projector \
    && mv $PROJECTOR_DIR/kotlin.js /usr/share/nginx/html/projector/ \
    && mv $PROJECTOR_DIR/kotlinx-serialization-kotlinx-serialization-runtime.js /usr/share/nginx/html/projector/ \
    && mv $PROJECTOR_DIR/projector-client-web.js /usr/share/nginx/html/projector/ \
    && mv $PROJECTOR_DIR/projector-common.js /usr/share/nginx/html/projector/ \
    && mv $PROJECTOR_DIR/index.html /usr/share/nginx/html/projector/ \
    && mv $PROJECTOR_DIR/pj.png /usr/share/nginx/html/projector/ \
# install packages:
    && apt-get update \
    && apt-get install libxext6 libxrender1 libxtst6 libxi6 libfreetype6 -y \
    && apt-get install patch -y \
    && apt-get install git -y \
# clean apt to reduce image size:
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt \
# change user to non-root (http://pjdietz.com/2016/08/28/nginx-in-docker-without-root.html):
    && patch /etc/nginx/nginx.conf < $PROJECTOR_DIR/nginx.conf.patch \
    && rm $PROJECTOR_DIR/nginx.conf.patch \
    && patch /etc/nginx/conf.d/default.conf < $PROJECTOR_DIR/site.conf.patch \
    && rm $PROJECTOR_DIR/site.conf.patch \
    && touch /var/run/nginx.pid \
    && mv $PROJECTOR_DIR/projector-user /home \
    && useradd -m -d /home/projector-user -s /bin/bash projector-user \
    && chown -R projector-user.projector-user /home/projector-user \
    && chown -R projector-user.projector-user $PROJECTOR_DIR \
    && chown -R projector-user.projector-user /usr/share/nginx \
    && chown -R projector-user.projector-user /var/cache/nginx \
    && chown -R projector-user.projector-user /var/run/nginx.pid \
    && chown projector-user.projector-user run.sh

USER projector-user
ENV HOME /home/projector-user
