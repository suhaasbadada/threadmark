"""Synthetic project: retain records for seven days."""


def normalize(value):
    return value.strip()


def submit(value):
    return normalize(value)


def dynamic(callback, value):
    return callback(value)
