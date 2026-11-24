FROM debian:latest
LABEL author="ahmad"

RUN apt-get update && apt-get install -y \
    bash \
    htop \
    vim \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

ENV OWNER=Ahmad

RUN useradd nonroot
USER nonroot

CMD ["sleep", "3600"]