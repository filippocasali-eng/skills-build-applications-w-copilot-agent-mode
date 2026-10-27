import * as React from "react";

/** Minimal Radix-style Slot: merges props and className onto its single child. */
export function Slot({ children, className, ...props }: React.HTMLAttributes<HTMLElement> & { children?: React.ReactNode }) {
  if (!React.isValidElement<{ className?: string }>(children)) return null;
  return React.cloneElement(children, {
    ...props,
    className: [className, children.props.className].filter(Boolean).join(" "),
  });
}
