# Версии
ARG RUNNER_VERSION=2.338.0

FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

# mc из релиза на GitHub: dl.min.io бинарники больше не раздаёт (проект MinIO в архиве)
ARG MC_VERSION=RELEASE.2025-08-13T08-35-41Z
ARG MC_SHA256=01f866e9c5f9b87c2b09116fa5d7c06695b106242d829a8bb32990c00312e891

USER root

RUN curl -fsSL "https://github.com/minio/mc/releases/download/${MC_VERSION}/mc.linux-amd64.${MC_VERSION}" \
      -o /usr/local/bin/mc \
    && echo "${MC_SHA256}  /usr/local/bin/mc" | sha256sum -c - \
    && chmod +x /usr/local/bin/mc \
    && mkdir /home/runner/state \
    && chown runner:runner /home/runner/state

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER runner

# HTTP-порта у runner'а нет: проверяем, что жив процесс Runner.Listener (связь с GitHub он держит сам).
# start-period покрывает регистрацию при первом старте
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD grep -qsx Runner.Listener /proc/[0-9]*/comm || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
