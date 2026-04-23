import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import Nav from "./Nav";

const mockLogout = vi.fn();

vi.mock("../AuthContext", () => ({
  useAuth: () => ({
    logout: mockLogout,
  }),
}));

function renderNav(path = "/", user = { name: "Tim", user_id: "user-1" }) {
  return render(
    <MemoryRouter initialEntries={[path]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
      <Nav user={user} />
    </MemoryRouter>
  );
}

describe("Nav", () => {
  it("renders navigation links", () => {
    renderNav();

    expect(screen.getByRole("link", { name: /chat/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /my trips/i })).toBeInTheDocument();
  });

  it("displays the user's name", () => {
    renderNav("/", { name: "Alice", user_id: "user-1" });

    expect(screen.getByText("Alice")).toBeInTheDocument();
  });

  it("highlights the chat link when on the chat page", () => {
    const link = render(
      <MemoryRouter initialEntries={["/"]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
        <Nav user={{ name: "Tim", user_id: "user-1" }} />
      </MemoryRouter>
    ).getByRole("link", { name: /chat/i });

    expect(link).toHaveClass("bg-blue-600");
  });

  it("highlights the trips link when on the trips page", () => {
    const link = render(
      <MemoryRouter initialEntries={["/trips"]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
        <Nav user={{ name: "Tim", user_id: "user-1" }} />
      </MemoryRouter>
    ).getByRole("link", { name: /my trips/i });

    expect(link).toHaveClass("bg-blue-600");
  });

  it("highlights the trips link when on a trip detail page", () => {
    const link = render(
      <MemoryRouter initialEntries={["/trips/trip-1"]} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
        <Nav user={{ name: "Tim", user_id: "user-1" }} />
      </MemoryRouter>
    ).getByRole("link", { name: /my trips/i });

    expect(link).toHaveClass("bg-blue-600");
  });

  it("calls logout when the logout button is clicked", async () => {
    const user = userEvent.setup();
    renderNav();

    const logoutButton = screen.getByRole("button");
    await user.click(logoutButton);

    expect(mockLogout).toHaveBeenCalled();
  });

  it("shows the brand name on desktop", () => {
    renderNav();

    expect(screen.getByText("Travel Assistant")).toBeInTheDocument();
  });
});
