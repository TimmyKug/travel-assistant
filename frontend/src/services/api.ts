import axios, { AxiosResponse } from "axios";
import type { Trip, Conversation, ConversationDetail, SendMessageResponse } from "../types";

const api = axios.create({ baseURL: "/api" });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);

export const sendMessage = (
  content: string,
  conversation_id: string | null = null
): Promise<SendMessageResponse> =>
  api.post("/ai/chat", { content, conversation_id }).then((r) => r.data);

export const listConversations = (): Promise<Conversation[]> =>
  api.get("/ai/conversations").then((r) => r.data);

export const getConversation = (id: string): Promise<ConversationDetail> =>
  api.get(`/ai/conversations/${id}`).then((r) => r.data);

export const listTrips = (): Promise<Trip[]> =>
  api.get("/trips/").then((r) => r.data);

export const createTrip = (data: Partial<Trip>): Promise<Trip> =>
  api.post("/trips/", data).then((r) => r.data);

export const updateTrip = (id: string, data: Partial<Trip>): Promise<Trip> =>
  api.put(`/trips/${id}`, data).then((r) => r.data);

export const deleteTrip = (id: string): Promise<AxiosResponse> =>
  api.delete(`/trips/${id}`);

export default api;
