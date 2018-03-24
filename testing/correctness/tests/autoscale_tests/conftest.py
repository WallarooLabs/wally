# Sort the tests alphabetically
def pytest_collection_modifyitems(session, config, items):
    items.sort(key=lambda i: i.name)
