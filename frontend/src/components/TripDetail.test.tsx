import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import TripDetail from "./TripDetail";
import { deleteTrip, getTrip, updateTrip } from "../services/api";
import { downloadTripMarkdown, formatTripMarkdown } from "../utils/tripMarkdown";

vi.mock("../services/api", () => ({
  getTrip: vi.fn(),
  updateTrip: vi.fn(),
  deleteTrip: vi.fn(),
}));

vi.mock("../utils/tripMarkdown", () => ({
  downloadTripMarkdown: vi.fn(),
  formatTripMarkdown: vi.fn(() => "# mock markdown"),
}));

function renderTripDetail(path = "/trips/trip-1") {
  return render(
    <MemoryRouter initialEntries={[path]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
      <Routes>
        <Route path="/trips/:tripId" element={<TripDetail />} />
        <Route path="/trips" element={<p>Trips Page</p>} />
      </Routes>
    </MemoryRouter>
  );
}

describe("TripDetail", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders a structured trip and supports export/open chat actions", async () => {
    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Budapest Escape",
      destination: "Budapest",
      conversation_id: "conv-1",
      itinerary: [
        {
          trip_title: "Budapest Escape",
          destination: "Budapest",
          summary: "A compact city break.",
          days: [
            {
              day: 1,
              items: [
                {
                  time: "16:00",
                  title: "Thermal Bath Visit",
                  description: "Relax at Szechenyi.",
                  category: "activity",
                },
              ],
            },
          ],
        } as Record<string, unknown>,
      ],
    });

    const user = userEvent.setup();
    renderTripDetail();

    expect((await screen.findAllByText("Budapest Escape")).length).toBeGreaterThan(0);
    expect(screen.getByText("Thermal Bath Visit")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /open chat/i })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /export \.md/i }));
    expect(formatTripMarkdown).toHaveBeenCalled();
    expect(downloadTripMarkdown).toHaveBeenCalledWith("# mock markdown", "Budapest Escape");
  });

  it("edits and saves plain trip details", async () => {
    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Initial Title",
      destination: "Initial Destination",
      notes: "Initial notes",
    });
    vi.mocked(updateTrip).mockResolvedValue({
      id: "trip-1",
      title: "Updated Title",
      destination: "Updated Destination",
      notes: "Updated notes",
    });

    const user = userEvent.setup();
    renderTripDetail();
    expect(await screen.findByText("Initial Title")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /edit/i }));
    await user.clear(screen.getByPlaceholderText(/title \*/i));
    await user.type(screen.getByPlaceholderText(/title \*/i), "Updated Title");
    await user.clear(screen.getByPlaceholderText(/destination/i));
    await user.type(screen.getByPlaceholderText(/destination/i), "Updated Destination");
    await user.clear(screen.getByPlaceholderText(/notes/i));
    await user.type(screen.getByPlaceholderText(/notes/i), "Updated notes");
    await user.click(screen.getByRole("button", { name: /^save$/i }));

    expect(updateTrip).toHaveBeenCalledWith(
      "trip-1",
      expect.objectContaining({
        title: "Updated Title",
        destination: "Updated Destination",
        notes: "Updated notes",
      })
    );
    expect(await screen.findByText("Updated Title")).toBeInTheDocument();
  });

  it("deletes a trip from detail view via confirmation modal", async () => {
    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Delete Me",
      destination: "Anywhere",
      notes: "Soon gone",
    });
    vi.mocked(deleteTrip).mockResolvedValue({} as Awaited<ReturnType<typeof deleteTrip>>);

    const user = userEvent.setup();
    renderTripDetail();
    expect(await screen.findByText("Delete Me")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /delete trip/i }));
    await user.click(screen.getByRole("button", { name: /^delete$/i }));

    expect(deleteTrip).toHaveBeenCalledWith("trip-1");
    expect(await screen.findByText("Trips Page")).toBeInTheDocument();
  });

  it("renders fallback text when no structured itinerary and no notes are present", async () => {
    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Empty Trip",
      destination: "Nowhere",
    });

    renderTripDetail();

    expect(await screen.findByText("Empty Trip")).toBeInTheDocument();
    expect(screen.getByText(/no details available for this trip yet/i)).toBeInTheDocument();
  });

  it("parses itinerary from JSON notes and saves edited structured fields", async () => {
    const structured = {
      trip_title: "Notes Plan",
      destination: "Seville",
      summary: "Initial summary",
      days: [
        {
          day: 1,
          items: [
            {
              time: "09:00",
              title: "Old Town Walk",
              description: "Explore",
              category: "activity",
            },
          ],
        },
      ],
    };

    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Plain title",
      destination: "Plain destination",
      notes: JSON.stringify(structured),
    });
    vi.mocked(updateTrip).mockResolvedValue({
      id: "trip-1",
      title: "Edited Notes Plan",
      destination: "Granada",
      notes: "Updated summary",
      itinerary: [
        {
          ...structured,
          trip_title: "Edited Notes Plan",
          destination: "Granada",
          summary: "Updated summary",
        } as Record<string, unknown>,
      ],
    });

    const user = userEvent.setup();
    renderTripDetail();
    expect(await screen.findByText("Plain title")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /edit/i }));
    await user.clear(screen.getByDisplayValue("Notes Plan"));
    await user.type(screen.getByPlaceholderText(/trip title \*/i), "Edited Notes Plan");
    await user.clear(screen.getByDisplayValue("Seville"));
    await user.type(screen.getByPlaceholderText(/destination/i), "Granada");
    await user.clear(screen.getByDisplayValue("Initial summary"));
    await user.type(screen.getByPlaceholderText(/trip summary/i), "Updated summary");
    await user.click(screen.getByRole("button", { name: /^save$/i }));

    expect(updateTrip).toHaveBeenCalledWith(
      "trip-1",
      expect.objectContaining({
        title: "Edited Notes Plan",
        destination: "Granada",
        notes: "Updated summary",
        itinerary: [
          expect.objectContaining({
            trip_title: "Edited Notes Plan",
            destination: "Granada",
            summary: "Updated summary",
          }),
        ],
      })
    );
  });

  it("shows an error when saving fails", async () => {
    vi.mocked(getTrip).mockResolvedValue({
      id: "trip-1",
      title: "Fail Save",
      destination: "Berlin",
      notes: "Initial notes",
    });
    vi.mocked(updateTrip).mockRejectedValue(new Error("save failed"));

    const user = userEvent.setup();
    renderTripDetail();
    expect(await screen.findByText("Fail Save")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /edit/i }));
    await user.click(screen.getByRole("button", { name: /^save$/i }));

    expect(await screen.findByText(/could not save trip changes/i)).toBeInTheDocument();
  });
});
