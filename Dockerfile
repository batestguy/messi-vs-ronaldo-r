# syntax=docker/dockerfile:1.7

FROM rocker/shiny-verse:4.5.0@sha256:ccafdf812938dc85891b198f0728c8bf1706f1b0b7558b9fe696e98eb116056a AS packages

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl \
      libssl-dev \
      libcurl4-openssl-dev \
      libxml2-dev \
      libfreetype6-dev \
      libharfbuzz-dev \
      libpng-dev \
      libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

ENV R_LIBS_USER=/opt/messi-library \
    R_LIBS_SITE=/opt/messi-library

RUN mkdir -p "${R_LIBS_SITE}" \
    && R -e 'options(repos = "https://packagemanager.posit.co/cran/2026-08-09"); install.packages(c("shiny", "bslib", "data.table", "htmltools", "plotly", "DT"), lib = Sys.getenv("R_LIBS_SITE"), dependencies = NA)' \
    && rm -rf /tmp/downloaded_packages


FROM rocker/shiny-verse:4.5.0@sha256:ccafdf812938dc85891b198f0728c8bf1706f1b0b7558b9fe696e98eb116056a AS runtime

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      curl \
      libssl-dev \
      libcurl4-openssl-dev \
      libxml2-dev \
      libfreetype6-dev \
      libharfbuzz-dev \
      libpng-dev \
      libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

ENV R_LIBS_USER=/opt/messi-library \
    R_LIBS_SITE=/opt/messi-library \
    SHINY_HOST=0.0.0.0 \
    SHINY_PORT=3838 \
    SHINY_SERVER_VERSION=1.5.24.1034 \
    R_PROFILE_USER=/opt/messi-vs-ronaldo/app/Rprofile.container \
    APP_DEBUG=false \
    APPLICATION_LOGS_TO_STDOUT=true

COPY --from=packages /opt/messi-library /opt/messi-library

WORKDIR /opt/messi-vs-ronaldo
COPY --chown=shiny:shiny app/ ./app/

USER shiny

EXPOSE 3838

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl --fail --silent --show-error http://127.0.0.1:3838/ >/dev/null || exit 1

CMD ["Rscript", "/opt/messi-vs-ronaldo/app/run.R"]
