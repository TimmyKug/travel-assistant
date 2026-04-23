import { describe, expect, it, beforeEach, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AuthProvider, useAuth } from "./AuthContext";

function TestComponent() {
  const { user, login, logout } = useAuth();

  return (
    <div>
      <div data-testid="user-status">{user ? `Logged in as ${user.name}` : "Not logged in"}</div>
      <button
        onClick={() => login({ name: "Tim", user_id: "user-1" }, "test-token")}
        data-testid="login-btn"
      >
        Login
      </button>
      <button onClick={logout} data-testid="logout-btn">
        Logout
      </button>
    </div>
  );
}

describe("AuthContext", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it("initializes with no user when localStorage is empty", () => {
    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    expect(screen.getByTestId("user-status")).toHaveTextContent("Not logged in");
  });

  it("hydrates user from localStorage on mount", () => {
    const testUser = { name: "Tim", user_id: "user-1" };
    localStorage.setItem("user", JSON.stringify(testUser));
    localStorage.setItem("token", "test-token");

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    expect(screen.getByTestId("user-status")).toHaveTextContent("Logged in as Tim");
  });

  it("logs in and persists to localStorage", async () => {
    const user = userEvent.setup();
    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    await user.click(screen.getByTestId("login-btn"));

    expect(screen.getByTestId("user-status")).toHaveTextContent("Logged in as Tim");
    expect(localStorage.getItem("token")).toBe("test-token");
    expect(JSON.parse(localStorage.getItem("user") ?? "{}")).toEqual({ name: "Tim", user_id: "user-1" });
  });

  it("logs out and clears localStorage", async () => {
    localStorage.setItem("token", "test-token");
    localStorage.setItem("user", JSON.stringify({ name: "Tim", user_id: "user-1" }));

    const user = userEvent.setup();
    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    expect(screen.getByTestId("user-status")).toHaveTextContent("Logged in as Tim");

    await user.click(screen.getByTestId("logout-btn"));

    expect(screen.getByTestId("user-status")).toHaveTextContent("Not logged in");
    expect(localStorage.getItem("token")).toBeNull();
    expect(localStorage.getItem("user")).toBeNull();
  });

  it("throws error when useAuth is used outside AuthProvider", () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    expect(() => {
      render(<TestComponent />);
    }).toThrow("useAuth must be used within AuthProvider");

    consoleError.mockRestore();
  });

  it("recovers from corrupted localStorage JSON", () => {
    localStorage.setItem("user", "{ invalid json");

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    expect(screen.getByTestId("user-status")).toHaveTextContent("Not logged in");
  });
});
