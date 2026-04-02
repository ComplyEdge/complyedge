#!/usr/bin/env python3
"""
Setup script for ComplyEdge Python SDK
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="complyedge",
    version="0.2.0",
    author="ComplyEdge",
    author_email="support@complyedge.com",
    description="Python SDK for ComplyEdge Compliance API",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/ComplyEdge/complyedge",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "httpx>=0.24.0",
        "tenacity>=8.0.0",
        "pydantic>=2.0.0",
    ],
    extras_require={
        "agents": [
            "openai-agents>=0.2.7",
        ],
        "dev": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
            "black>=23.0.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
        ],
        "testing": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
        ],
        "complete": [
            "openai-agents>=0.2.7",
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
        ],
    },
)
