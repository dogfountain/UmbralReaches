"""Recipe registry: @recipe(category, id) on a function returning an (N, N, 3) float image."""
RECIPES = {}


def recipe(category, ident):
    def deco(fn):
        RECIPES[(category, ident)] = fn
        return fn
    return deco
