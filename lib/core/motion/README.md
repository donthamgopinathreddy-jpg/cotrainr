# Motion System Usage Guide

## Quick Reference

### Using AnimatedPageContent
Wrap your page content to add entry animations:
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: AnimatedPageContent(
      child: YourPageContent(),
    ),
  );
}
```

### Using StaggeredListItem
Wrap list items for staggered animations:
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return StaggeredListItem(
      index: index,
      child: YourListItem(items[index]),
    );
  },
)
```

### Using PressableCard
For cards with press feedback:
```dart
PressableCard(
  onTap: () => navigate(),
  hapticType: HapticFeedbackType.selectionClick,
  child: YourCardContent(),
)
```

### Using AnimatedCard
For more complex card needs:
```dart
AnimatedCard(
  onTap: () => action(),
  onLongPress: () => showContextMenu(),
  backgroundColor: Colors.white,
  child: YourCardContent(),
)
```

### Using SwipeBackDetector
Enable swipe-back navigation:
```dart
SwipeBackDetector(
  child: YourPageContent(),
)
```

### Using DraggableBottomSheet
Show bottom sheets with drag-to-dismiss:
```dart
DraggableBottomSheet.show(
  context: context,
  builder: (context) => YourBottomSheetContent(),
)
```

## Motion Constants

### Durations
- `Motion.fast` - 150ms (micro-interactions)
- `Motion.standard` - 250ms (standard transitions)
- `Motion.smooth` - 300ms (smooth transitions)
- `Motion.slow` - 400ms (complex animations)

### Curves
- `Motion.primaryCurve` - easeOutCubic (most animations)
- `Motion.springCurve` - easeOutBack (bouncy animations)
- `Motion.snapCurve` - easeOut (snappy interactions)

### Press Interactions
- `Motion.pressScale` - 0.98 (scale on press)
- `Motion.pressDuration` - 120ms
- `Motion.pressCurve` - easeOut

### Stagger Helpers
- `Motion.staggerDelayFor(index)` - Calculate delay for item at index
- `Motion.staggerDelay` - 50ms per item
- `Motion.staggerInitialDelay` - 100ms initial delay
