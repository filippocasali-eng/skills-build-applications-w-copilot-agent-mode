// @vitest-environment jsdom
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AnswerButton } from "@/components/game/AnswerButton";
import { ErrorPanel } from "@/components/game/ErrorPanel";
import { ProgressSegments } from "@/components/game/ProgressSegments";

describe("AnswerButton", () => {
  it("exposes an accessible name and reports its index on click", () => {
    const onSelect = vi.fn();
    render(<AnswerButton index={2} text="Marte" state="idle" disabled={false} onSelect={onSelect} ariaLabel="Risposta C: Marte" />);
    fireEvent.click(screen.getByRole("button", { name: "Risposta C: Marte" }));
    expect(onSelect).toHaveBeenCalledWith(2);
  });

  it("cannot be clicked once answers are locked", () => {
    const onSelect = vi.fn();
    render(<AnswerButton index={0} text="Venere" state="wrong" disabled onSelect={onSelect} ariaLabel="A" />);
    const btn = screen.getByRole("button");
    expect(btn).toBeDisabled();
    expect(btn).toHaveAttribute("data-state", "wrong");
    fireEvent.click(btn);
    expect(onSelect).not.toHaveBeenCalled();
  });
});

describe("ErrorPanel", () => {
  it("shows a localized message for network errors and offers a new game", () => {
    const onRetry = vi.fn();
    render(<ErrorPanel code="NETWORK" onRetry={onRetry} />);
    expect(screen.getByRole("alert")).toHaveTextContent("Connessione assente");
    fireEvent.click(screen.getByRole("button", { name: /Nuova partita/ }));
    expect(onRetry).toHaveBeenCalled();
  });
});

describe("ProgressSegments", () => {
  it("renders one segment per question", () => {
    const { container } = render(<ProgressSegments total={10} current={2} slots={["correct", "wrong"]} />);
    expect(container.firstElementChild?.children).toHaveLength(10);
  });
});
