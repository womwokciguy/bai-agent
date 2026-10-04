FROM nousresearch/hermes-agent:latest
ENV HERMES_HOME=/opt/data

COPY requirements-proxy.txt /tmp/requirements-proxy.txt
RUN uv pip install --python /opt/hermes/.venv/bin/python --no-cache-dir -r /tmp/requirements-proxy.txt

COPY bai_proxy.py /opt/bai_proxy.py
COPY bai_apikeys.txt /opt/bai_apikeys.txt
COPY provider.conf /opt/data/provider.conf
COPY bootstrap.sh /opt/bootstrap.sh
RUN chmod +x /opt/bootstrap.sh

CMD ["/opt/bootstrap.sh"]

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
