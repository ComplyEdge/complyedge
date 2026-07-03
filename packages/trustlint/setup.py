from setuptools import setup, find_packages
from pathlib import Path

this_dir = Path(__file__).parent
long_desc = (this_dir / "README.md").read_text(encoding="utf-8")

setup(
    name="trustlint",
    version="2.0.0",
    packages=find_packages(),
    # Ship the ComplyEdge rule corpus inside the wheel so `pip install
    # trustlint` is a self-contained linter. trustlint/rules/ is populated at
    # build time from the canonical rules/regulations/ corpus (deploy-pip.sh).
    include_package_data=True,
    package_data={"trustlint": ["rules/**/*.yaml", "rules/**/*.yml"]},
    python_requires=">=3.9",
    install_requires=[
        "click>=8.0",
        "pyyaml>=6.0",
    ],
    entry_points={
        "console_scripts": [
            "trustlint=trustlint.cli:main",
        ],
    },
    long_description=long_desc,
    long_description_content_type="text/markdown",
    description="Offline compliance linter for AI agents — scans text against the ComplyEdge rule corpus",
    author="ComplyEdge",
    author_email="support@complyedge.io",
    url="https://github.com/ComplyEdge/complyedge",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Quality Assurance",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
)
