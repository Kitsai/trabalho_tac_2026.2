FROM apache/rocketmq:5.1.0

USER root

# CentOS 7 is EOL; the mirrorlist is dead, point yum at the vault instead.
RUN sed -i \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        /etc/yum.repos.d/CentOS-*.repo \
    && yum install -y sudo gcc httpd \
    && yum clean all

# --- Thematic landing page (no exploit here, purely cosmetic) ---------------
COPY docker/www/index.html /var/www/html/index.html
RUN echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf

# --- Rename rocketmq -> james (uid/gid 3000 unchanged) -----------------------
# Must run BEFORE any --chown=james:... COPY below. `usermod -m` physically
# MOVES /home/rocketmq to /home/james (including rocketmq-5.1.0 inside it).
# CRITICAL: the base image bakes ROCKETMQ_HOME in as the literal string
# /home/rocketmq/rocketmq-5.1.0 via ENV. That does NOT follow the rename
# automatically -- without re-declaring it, mqbroker's own launcher (which
# only self-detects ROCKETMQ_HOME `if [ -z "$ROCKETMQ_HOME" ]`) will silently
# use the stale, now-nonexistent path and fail to boot.
RUN usermod -l james -d /home/james -m rocketmq \
    && groupmod -n james rocketmq
ENV ROCKETMQ_HOME=/home/james/rocketmq-5.1.0
WORKDIR /home/james/rocketmq-5.1.0/bin

# --- Off-default ports -------------------------------------------------------
# RocketMQ doesn't sit on its textbook ports 9876/10911 here; the real
# assignment is only visible on the landing page memo.
COPY --chown=james:james docker/namesrv.conf ${ROCKETMQ_HOME}/conf/namesrv.conf
COPY --chown=james:james docker/broker.conf ${ROCKETMQ_HOME}/conf/broker.conf

# --- Second user: giovanni (Team Rocket's boss) ------------------------------
RUN useradd -m giovanni \
    && echo "giovanni:PersianPurrs2026!" | chpasswd

# --- Stego clue: a "voicemail from the boss" hidden in james's home ---------
RUN mkdir -p /home/james/Voicemails \
    && chown james:james /home/james/Voicemails \
    && chmod 750 /home/james/Voicemails
COPY --chown=james:james docker/secrets/boss_memo.wav /home/james/Voicemails/boss_memo.wav
RUN chmod 640 /home/james/Voicemails/boss_memo.wav

# --- Privilege-escalation path: sudo secure_path misconfig + PATH hijack ----
# giovanni may run /opt/giovanni-tools/report.sh as root via sudo. The
# sudoers rule also sets secure_path to a list that starts with a directory
# giovanni owns, letting him shadow any bare command the script calls.
RUN mkdir -p /opt/giovanni-tools/bin \
    && chown root:root /opt/giovanni-tools \
    && chmod 755 /opt/giovanni-tools \
    && chown giovanni:giovanni /opt/giovanni-tools/bin \
    && chmod 755 /opt/giovanni-tools/bin

COPY docker/report.sh /opt/giovanni-tools/report.sh
RUN chown root:root /opt/giovanni-tools/report.sh \
    && chmod 755 /opt/giovanni-tools/report.sh

COPY docker/sudoers.giovanni /etc/sudoers.d/giovanni
RUN chown root:root /etc/sudoers.d/giovanni \
    && chmod 440 /etc/sudoers.d/giovanni \
    && visudo -c

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

# --- Flags --------------------------------------------------------------
RUN echo "flag{meowth_that_s_r1ght_unauth_rce}" > /home/james/user.txt \
    && chown james:james /home/james/user.txt \
    && chmod 400 /home/james/user.txt
RUN echo "flag{s3cure_path_isnt_s0_s3cure}" > /root/root.txt \
    && chmod 400 /root/root.txt

EXPOSE 80 47280 47293
ENTRYPOINT ["/entrypoint.sh"]
