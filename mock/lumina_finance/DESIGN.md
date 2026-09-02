---
name: Lumina Finance
colors:
  surface: '#f9f9f8'
  surface-dim: '#dadad9'
  surface-bright: '#f9f9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f3'
  surface-container: '#eeeeed'
  surface-container-high: '#e8e8e7'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#49454e'
  inverse-surface: '#2f3130'
  inverse-on-surface: '#f1f1f0'
  outline: '#7a757f'
  outline-variant: '#cbc4cf'
  surface-tint: '#675688'
  primary: '#352553'
  on-primary: '#ffffff'
  primary-container: '#4c3b6b'
  on-primary-container: '#bca7df'
  inverse-primary: '#d2bdf6'
  secondary: '#5f5d69'
  on-secondary: '#ffffff'
  secondary-container: '#e5e0ef'
  on-secondary-container: '#65636f'
  tertiary: '#735c00'
  on-tertiary: '#ffffff'
  tertiary-container: '#cca72f'
  on-tertiary-container: '#4e3d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ebdcff'
  primary-fixed-dim: '#d2bdf6'
  on-primary-fixed: '#221140'
  on-primary-fixed-variant: '#4f3e6e'
  secondary-fixed: '#e5e0ef'
  secondary-fixed-dim: '#c9c4d3'
  on-secondary-fixed: '#1c1a25'
  on-secondary-fixed-variant: '#474551'
  tertiary-fixed: '#ffe088'
  tertiary-fixed-dim: '#e9c349'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#574500'
  background: '#f9f9f8'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 120px
---

## Brand & Style

The design system is crafted for micro-entrepreneurs who seek clarity and calm in their financial management. The personality is **warm, human, and elegant**, intentionally moving away from the cold, sterile aesthetics of traditional banking.

The design style is **Modern Minimalist with iOS-inspired flatness**. It prioritizes generous whitespace and a clear information hierarchy to reduce cognitive load. Visual interest is generated through sophisticated color pairings and soft shapes rather than complex textures or heavy shadows. The emotional response should be one of empowerment and approachability—making financial data feel like a supportive conversation rather than a rigid ledger.

## Colors

The palette is anchored by a **Deep Elegant Violet** primary color, chosen for its association with wisdom and stability without the "tech" aggression of neon purples. 

- **Primary (#4C3B6B):** Used for primary actions, active navigation states, and brand-heavy components.
- **Secondary (#E6E1F0):** A soft lavender used for subtle backgrounds, secondary buttons, and chip elements.
- **Background (#F9F9F8):** An off-white base that provides a warmer, more human feel than pure white.
- **Accents:** 
    - **Warm Gold (#D4AF37):** Used for positive trends, rewards, or premium indicators.
    - **Soft Coral (#F08080):** Replaces traditional red for alerts and negative trends to keep the tone encouraging and less stressful.

## Typography

This design system utilizes **Inter** for its exceptional legibility and modern, neutral character that allows the brand colors and shapes to lead. 

Typography follows a strict hierarchy to help entrepreneurs scan financial data quickly. **Display** and **Headline** styles use tighter letter spacing and heavier weights to feel grounded. **Body** text is set with generous line heights to maintain the "airy" feel of the brand. For mobile devices, large headlines scale down to ensure content remains above the fold while maintaining the high-contrast relationship between titles and body text.

## Layout & Spacing

The layout philosophy relies on a **Fluid Grid** with generous margins to create a "contained" and safe feeling. 

- **Mobile:** A 4-column grid with 20px side margins. Elements typically span the full width to maximize readability.
- **Desktop:** A 12-column grid centered in a max-width container (1440px). Side margins expand significantly to maintain the minimalist focus.

Spacing follows an 8px rhythmic scale. We prioritize **Large (40px)** and **Extra Large (64px)** vertical gaps between major sections to emphasize the "Minimalist" brand pillar and prevent the UI from feeling cluttered with data.

## Elevation & Depth

In alignment with iOS flat design, this design system avoids heavy drop shadows. Depth is communicated through **Tonal Layering** and **Soft Outlines**.

- **Surface 1 (Base):** The Off-White background.
- **Surface 2 (Cards):** Pure white surfaces placed on the off-white background.
- **Subtle Definition:** Instead of shadows, cards use a 1px border colored at a 5% tint of the Primary Violet, or a very faint, large-radius ambient glow (Opacity 4%, Blur 20px) to indicate interactivity.
- **Active State:** Elements may slightly scale (1.02x) or shift in tonal value rather than "lifting" off the page.

## Shapes

The shape language is defined by **Soft Roundedness**. 

- **Standard Elements (Buttons, Inputs):** 16px corner radius.
- **Containers (Cards, Modals):** 24px corner radius (`rounded-xl`).
- **Small Elements (Chips, Tags):** Full pill-shape for high contrast against rectangular content blocks.

These radii are significantly softer than standard corporate systems to evoke a friendly, human feel that mirrors modern consumer hardware.

## Components

### Buttons
- **Primary:** Deep Violet background with white text. Flat design (no gradients).
- **Secondary:** Soft Lavender background with Deep Violet text.
- **Tertiary:** Text-only with a 1px underline on hover, using Primary color.

### Cards
Cards are the primary container for financial data. They must feature 24px padding and 24px rounded corners. Borders are preferred over shadows—use a subtle #E6E1F0 border to define the card boundaries against the background.

### Inputs
Input fields use the secondary color (#E6E1F0) at 30% opacity for the background to create a "well" effect. They feature 16px rounding and transition to a 2px Primary Violet border when focused.

### Chips & Badges
Used for categorizing transactions. These are always pill-shaped. Backgrounds use highly desaturated versions of the accent colors (e.g., very pale gold background with gold text) to maintain elegance.

### Simple Icons
Icons should use a "Thin" or "Light" stroke weight (1.5px) with rounded ends. Avoid filled icons unless indicating an active state in the bottom navigation bar.

### Encouragement Banners
Small, card-like components using the Warm Gold or Soft Lavender background to provide "Nudges" or positive feedback to the entrepreneur (e.g., "You've saved 10% more this month!").