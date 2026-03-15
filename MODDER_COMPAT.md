# Ice Cold Beer Modder Compatibility

Ice Cold Beer can detect third-party drinks if you opt your item in with tags.

## Required Tag

Add this tag to the drink item:

```text
icecoldbeer:bettercold
```

This tells Ice Cold Beer that the drink should be considered a valid cold-target.

## Optional Tags

You can also provide a category or explicit suggested bonus values.

### Category Tag

```text
icecoldbeer:category/beer
```

Supported category keys:

- `beer`
- `white_wine`
- `champagne`
- `cider`
- `soda`
- `bottled_soda`
- `juice`
- `milk`
- `personal_milk`
- `chocolate_milk`

If you provide a category tag, Ice Cold Beer will use the player's configured bonus values for that category.

### Explicit Suggested Bonus Tags

```text
icecoldbeer:unhappiness/3
icecoldbeer:boredom/2
```

Rules:

- allowed range is `0-100`
- values outside that range are clamped
- explicit values override category defaults

## Fallback Behavior

If you only provide:

```text
icecoldbeer:bettercold
```

then Ice Cold Beer will use its generic custom-target default bonus values.

## Recommended Use

Use the tag contract for drinks that are clearly intended to be enjoyed cold, such as:

- beer
- canned or bottled soda
- juice
- milk
- cold wine or sparkling drinks

Do not use it for drinks that are intended to be hot or warm, or for items that are technically drinkable but not a good "better cold" fit.

## Example

```text
Tags = base:cookable;base:hasmetal;base:sealedbeveragecan;icecoldbeer:bettercold;icecoldbeer:category/soda,
```

Or with explicit values:

```text
Tags = base:glass;base:glassbottle;icecoldbeer:bettercold;icecoldbeer:unhappiness/4;icecoldbeer:boredom/2,
```
