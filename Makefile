clean:
	rm -rf *.so scurl/*.so build scurl/*.c scurl/*.cpp scurl/*.html dist .cache tests/__pycache__ *.rst

test:
	py.test tests/ -v

build_ext:
	python setup.py build_ext --inplace

sdist:
	python setup.py sdist

install:
	python setup.py install

develop:
	python setup.py develop

perf:
	python benchmarks/performance_test.py

cano:
	python benchmarks/canonicalize_test.py
