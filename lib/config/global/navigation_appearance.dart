const minNavigationTransparency = 2;
const maxNavigationTransparency = 50;
const defaultNavigationTransparency = 6;

int normalizeNavigationTransparency(Object? value) => value is int
    ? value.clamp(minNavigationTransparency, maxNavigationTransparency)
    : defaultNavigationTransparency;
