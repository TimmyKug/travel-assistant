import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import Chat from "./Chat";
import { createTrip, listTrips, sendMessage, updateTrip } from "../services/api";

vi.mock("../services/api", () => ({
  listConversations: vi.fn().mockResolvedValue([]),
  listTrips: vi.fn().mockResolvedValue([]),
  getConversation: vi.fn(),
  createTrip: vi.fn(),
  updateTrip: vi.fn(),
  sendMessage: vi.fn(),
}));

function renderChat() {
  return render(
    <MemoryRouter future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
      <Chat />
    </MemoryRouter>
  );
}

describe("Chat", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(listTrips).mockResolvedValue([]);
  });

  it("shows saved when assistant itinerary matches the linked trip itinerary", async () => {
    const sharedPlan = {
      trip_title: "Rome Escape",
      destination: "Rome",
      summary: "2 days",
      days: [{ day: 1, items: [] }],
    };

    vi.mocked(sendMessage).mockResolvedValue({
      conversation_id: "conversation-1",
      assistant_message: JSON.stringify(sharedPlan),
      recommendations: ["Continue planning"],
      trip_plan: sharedPlan,
    });
    vi.mocked(listTrips).mockResolvedValue([
      {
        id: "trip-linked",
        title: "Rome Escape",
        destination: "Rome",
        conversation_id: "conversation-1",
        itinerary: [sharedPlan as unknown as Record<string, unknown>],
      },
    ]);

    const user = userEvent.setup();
    renderChat();
    await user.type(screen.getByPlaceholderText(/ask about destinations/i), "Plan Rome{Enter}");

    const savedButton = await screen.findByRole("button", { name: /open trip/i });
    expect(savedButton).toBeInTheDocument();
    await user.click(savedButton);
    expect(screen.queryByRole("heading", { name: /save as trip/i })).not.toBeInTheDocument();
  });

  it("shows update trip for a new itinerary and overwrites the linked trip itinerary", async () => {
    const newPlan = {
      trip_title: "Rome v2",
      destination: "Rome",
      summary: "3 days",
      days: [{ day: 1, items: [{ time: "10:00", title: "Colosseum", description: "Visit", category: "activity" }] }],
    };
    vi.mocked(sendMessage).mockResolvedValue({
      conversation_id: "conversation-1",
      assistant_message: JSON.stringify(newPlan),
      recommendations: ["Continue planning"],
      trip_plan: newPlan,
    });
    vi.mocked(listTrips).mockResolvedValue([
      {
        id: "trip-linked",
        title: "Rome Escape",
        destination: "Rome",
        conversation_id: "conversation-1",
        itinerary: [
          {
            trip_title: "Rome Escape",
            destination: "Rome",
            summary: "2 days",
            days: [{ day: 1, items: [] }],
          } as unknown as Record<string, unknown>,
        ],
      },
    ]);
    vi.mocked(updateTrip).mockResolvedValue({
      id: "trip-linked",
      title: "Rome v2",
      destination: "Rome",
      conversation_id: "conversation-1",
    });

    const user = userEvent.setup();
    renderChat();
    await user.type(screen.getByPlaceholderText(/ask about destinations/i), "Plan Rome{Enter}");

    const updateButton = await screen.findByRole("button", { name: /update trip/i });
    expect(updateButton).toBeInTheDocument();
    await user.click(updateButton);

    expect(updateTrip).toHaveBeenCalledWith(
      "trip-linked",
      expect.objectContaining({
        title: "Rome v2",
        destination: "Rome",
        notes: "3 days",
        itinerary: [expect.objectContaining({ trip_title: "Rome v2" })],
        conversation_id: "conversation-1",
      })
    );
  });

  it("sends a user message and shows the assistant response", async () => {
    vi.mocked(sendMessage).mockResolvedValue({
      conversation_id: "conversation-1",
      assistant_message: "You should visit Lisbon.",
      recommendations: ["Find Lisbon stays", "Build Lisbon budget"],
    });

    const user = userEvent.setup();
    renderChat();

    await user.type(
      screen.getByPlaceholderText(/ask about destinations/i),
      "Where should I go?{Enter}"
    );

    expect(sendMessage).toHaveBeenCalledWith("Where should I go?", null, "trip_json");
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
      assistant_message: JSON.stringify({
        trip_title: "Porto Budget Escape",
        destination: "Porto",
        summary: "3 days",
        days: [
          {
            day: 1,
            items: [
              {
                time: "09:00",
                title: "Ribeira Walk",
                description: "Explore the old town",
                category: "activity",
                estimated_cost: "0",
              },
            ],
          },
        ],
        budget: { currency: "EUR", estimated_total: "250" },
      }),
      recommendations: ["Porto food day", "Cheap Porto hotels"],
      trip_plan: {
        trip_title: "Porto Budget Escape",
        destination: "Porto",
        summary: "3 days",
        days: [
          {
            day: 1,
            items: [
              {
                time: "09:00",
                title: "Ribeira Walk",
                description: "Explore the old town",
                category: "activity",
                estimated_cost: "0",
              },
            ],
          },
        ],
        budget: { currency: "EUR", estimated_total: "250" },
      },
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

    await user.clear(within(modal!).getByPlaceholderText(/trip title/i));
    await user.type(within(modal!).getByPlaceholderText(/trip title/i), "Porto");
    await user.clear(within(modal!).getByPlaceholderText(/destination/i));
    await user.type(within(modal!).getByPlaceholderText(/destination/i), "Porto");
    await user.click(within(modal!).getByRole("button", { name: /^save trip$/i }));

    expect(createTrip).toHaveBeenCalledWith({
      title: "Porto",
      destination: "Porto",
      notes: "3 days",
      itinerary: [
        expect.objectContaining({
          trip_title: "Porto Budget Escape",
          destination: "Porto",
        }),
      ],
      conversation_id: "conversation-1",
    });
    expect(await screen.findByRole("button", { name: /saved/i })).toBeInTheDocument();
  });
});
