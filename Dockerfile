FROM nousresearch/hermes-agent:latest

ENV HERMES_HOME=/opt/data

COPY bootstrap.sh /opt/bootstrap.sh
COPY add_provider.py /opt/add_provider.py
RUN chmod +x /opt/bootstrap.sh

CMD ["/opt/bootstrap.sh"]
