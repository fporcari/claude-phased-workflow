from textutils.slugify import slugify


def test_basic():
    assert slugify("Hello World") == "hello-world"


def test_accents_stripped():
    assert slugify("Citta di Firenze") == "citta-di-firenze"


def test_custom_separator():
    assert slugify("Hello World", separator="_") == "hello_world"


def test_empty():
    assert slugify("") == ""
