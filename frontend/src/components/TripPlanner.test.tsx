import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import TripPlanner from "./TripPlanner";
import { createTrip, deleteTrip, listTrips } from "../services/api";

vi.mock("../services/api", () => ({
  listTrips: vi.fn(),
  createTrip: vi.fn(),
  updateTrip: vi.fn(),
  deleteTrip: vi.fn(),
}));

function renderTripPlanner() {
  return render(
    <MemoryRouter>
      <TripPlanner />
    </MemoryRouter>
  );
}

describe("TripPlanner", () => {
  it("creates a new trip and adds it to the list", async () => {
    vi.mocked(listTrips).mockResolvedValue([]);
    vi.mocked(createTrip).mockResolvedValue({
      id: "trip-1",
      title: "Berlin Weekend",
      destination: "Berlin",
    });

    const user = userEvent.setup();
    renderTripPlanner();

    await user.click(screen.getByRole("button", { name: /new trip/i }));
    await user.type(screen.getByPlaceholderText(/trip title/i), "Berlin Weekend");
    await user.type(screen.getByPlaceholderText(/destination/i), "Berlin");
    await user.click(screen.getByRole("button", { name: /save/i }));

    expect(createTrip).toHaveBeenCalledWith({
      title: "Berlin Weekend",
      destination: "Berlin",
    });
    expect(await screen.findByText("Berlin Weekend")).toBeInTheDocument();
    expect(screen.getByText("Berlin")).toBeInTheDocument();
  });

  it("deletes an existing trip from the list", async () => {
    vi.mocked(listTrips).mockResolvedValue([
      {
        id: "trip-1",
        title: "Lisbon Notes",
        destination: "Lisbon",
      },
    ]);
    vi.mocked(deleteTrip).mockResolvedValue({} as Awaited<ReturnType<typeof deleteTrip>>);

    const user = userEvent.setup();
    renderTripPlanner();

    expect(await screen.findByText("Lisbon Notes")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /delete trip/i }));

    expect(deleteTrip).toHaveBeenCalledWith("trip-1");
    expect(screen.queryByText("Lisbon Notes")).not.toBeInTheDocument();
  });
});
