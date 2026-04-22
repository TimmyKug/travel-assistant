import { describe, expect, it, vi } from "vitest";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import Chat from "./Chat";
import { createTrip, sendMessage } from "../services/api";

vi.mock("../services/api", () => ({
  listConversations: vi.fn().mockResolvedValue([]),
  getConversation: vi.fn(),
  createTrip: vi.fn(),
  sendMessage: vi.fn(),
}));

function renderChat() {
  return render(
    <MemoryRouter>
      <Chat />
    </MemoryRouter>
  );
}

describe("Chat", () => {
  it("sends a user message and shows the assistant response", async () => {
    vi.mocked(sendMessage).mockResolvedValue({
      conversation_id: "conversation-1",
      assistant_message: "You should visit Lisbon.",
    });

    const user = userEvent.setup();
    renderChat();

    await user.type(
      screen.getByPlaceholderText(/ask about destinations/i),
      "Where should I go?{Enter}"
    );

    expect(sendMessage).toHaveBeenCalledWith("Where should I go?", null);
    expect(await screen.findByText("You should visit Lisbon.")).toBeInTheDocument();
  });

  it("shows a friendly limit message when the AI endpoint returns 429", async () => {
    vi.mocked(sendMessage).mockRejectedValue({ response: { status: 429 } });

    const user = userEvent.setup();
    renderChat();

    await user.type(
      screen.getByPlaceholderText(/ask about destinations/i),
      "Plan my trip{Enter}"
    );

    expect(await screen.findByText(/daily ai request limit reached/i)).toBeInTheDocument();
  });

  it("saves an assistant response as a trip", async () => {
    vi.mocked(sendMessage).mockResolvedValue({
      conversation_id: "conversation-1",
      assistant_message: "Spend three days exploring Porto.",
    });
    vi.mocked(createTrip).mockResolvedValue({
      id: "trip-1",
      title: "Porto",
      destination: "Porto",
      notes: "Spend three days exploring Porto.",
      conversation_id: "conversation-1",
    });

    const user = userEvent.setup();
    renderChat();

    await user.type(
      screen.getByPlaceholderText(/ask about destinations/i),
      "Give me a Porto idea{Enter}"
    );
    await user.click(await screen.findByRole("button", { name: /save as trip/i }));
    const modal = screen.getByRole("heading", { name: /save as trip/i }).closest("div");
    expect(modal).not.toBeNull();

    await user.type(within(modal!).getByPlaceholderText(/trip title/i), "Porto");
    await user.type(within(modal!).getByPlaceholderText(/destination/i), "Porto");
    await user.click(within(modal!).getByRole("button", { name: /^save trip$/i }));

    expect(createTrip).toHaveBeenCalledWith({
      title: "Porto",
      destination: "Porto",
      notes: "Spend three days exploring Porto.",
      conversation_id: "conversation-1",
    });
    expect(await screen.findByRole("button", { name: /saved/i })).toBeInTheDocument();
  });
});
