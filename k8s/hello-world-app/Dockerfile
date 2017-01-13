FROM ubuntu:xenial

RUN apt-get update && apt-get install -y python python-pip

ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt

EXPOSE 7892

WORKDIR /home/fivestars/hello-world-app

CMD python run.py