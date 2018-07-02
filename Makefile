clean:
	rm -rf *.so scurl/*.so build scurl/*.c scurl/*.cpp scurl/*.html dist .cache tests/__pycache__ *.rst

benchmark:
	python benchmarks/urls.py

test:
	py.test tests/ -v

docker_build:
	docker build -t commonsearch/scurl .

docker_shell:
	docker run -v "$(PWD):/cosr/scurl:rw" -w /cosr/scurl -i -t nctl144/scurl bash

docker_test:
	docker run -v "$(PWD):/cosr/scurl:rw" -w /cosr/scurl -i -t nctl144/scurl make test

docker_benchmark:
	docker run -v "$(PWD):/cosr/scurl:rw" -w /cosr/scurl -i -t nctl144/scurl make benchmark

build_ext:
	python setup.py build_ext --inplace

sdist:
	python setup.py sdist

pypi: clean build_ext
	pip install pypandoc
	python setup.py sdist upload -r pypi-commonsearch

install:
	python setup.py install
