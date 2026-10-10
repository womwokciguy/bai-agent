FROM nousresearch/hermes-agent:latest

ENV HERMES_HOME=/opt/data

COPY bootstrap.sh /opt/bootstrap.sh
RUN chmod +x /opt/bootstrap.sh

CMD ["/opt/bootstrap.sh"]
