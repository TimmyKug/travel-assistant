import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "./App";
import { AuthProvider } from "./AuthContext";

vi.mock("./services/api", () => ({
  listConversations: vi.fn().mockResolvedValue([]),
  listTrips: vi.fn().mockResolvedValue([]),
}));

function renderApp(path = "/") {
  return render(
    <MemoryRouter
      initialEntries={[path]}
      future={{ v7_relativeSplatPath: true, v7_startTransition: true }}
    >
      <AuthProvider>
        <App />
      </AuthProvider>
    </MemoryRouter>
  );
}

describe("App routing", () => {
  it("shows the login screen when the user is not authenticated", () => {
    renderApp("/");

    expect(screen.getByRole("heading", { name: /ai travel assistant/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });

  it("shows protected routes when the user is authenticated", async () => {
    localStorage.setItem("token", "test-token");
    localStorage.setItem("user", JSON.stringify({ name: "Tim", user_id: "user-1" }));

    renderApp("/trips");

    expect(await screen.findByRole("heading", { name: /my trips/i })).toBeInTheDocument();
    expect(screen.getByText("Tim")).toBeInTheDocument();
  });
});
