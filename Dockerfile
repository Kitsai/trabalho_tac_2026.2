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

# --- Off-default ports -------------------------------------------------------
# RocketMQ doesn't sit on its textbook ports 9876/10911 here; the real
# assignment is only visible on the landing page memo.
COPY --chown=rocketmq:rocketmq docker/namesrv.conf ${ROCKETMQ_HOME}/conf/namesrv.conf
COPY --chown=rocketmq:rocketmq docker/broker.conf ${ROCKETMQ_HOME}/conf/broker.conf

# --- A leftover TODO note, world-readable, left by james --------------------
# The RCE lands as "rocketmq"; this is how that foothold finds a path to a
# named user. James was told to rotate this password and never got to it.
RUN mkdir -p /opt/notes && chmod 755 /opt/notes
COPY docker/todo.txt /opt/notes/todo.txt
RUN chmod 644 /opt/notes/todo.txt

# --- Second user: james (uid/gid auto-assigned, no collision with rocketmq) -
RUN useradd -m james \
    && echo "james:Secret123" | chpasswd

# --- Third user: giovanni (Team Rocket's boss) -------------------------------
RUN useradd -m giovanni \
    && echo "giovanni:PersianPurrs2026!" | chpasswd

# --- Stego clue: a "voicemail from the boss" hidden in james's home ---------
# Deliberately misleading extension (.dat, not .wav) -- `file` reveals the
# real type (RIFF/WAVE) regardless of what the name claims.
RUN mkdir -p /home/james/Voicemails \
    && chown james:james /home/james/Voicemails \
    && chmod 750 /home/james/Voicemails
COPY --chown=james:james docker/secrets/announcement.dat /home/james/Voicemails/announcement.dat
RUN chmod 640 /home/james/Voicemails/announcement.dat

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
RUN echo "TAC{meowth_that_s_r1ght_unauth_rce}" > /home/rocketmq/user.txt \
    && chown rocketmq:rocketmq /home/rocketmq/user.txt \
    && chmod 400 /home/rocketmq/user.txt
RUN echo "TAC{EQu1pe_R0cK3t_d3cOL4nd0_d3_N0vo}" > /root/root.txt \
    && chmod 400 /root/root.txt

EXPOSE 80 47280 47293
ENTRYPOINT ["/entrypoint.sh"]
