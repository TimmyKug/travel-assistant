import axios from "axios";
import { getAuth } from "firebase/auth";

const api = axios.create({ baseURL: "/api" });

api.interceptors.request.use(async (config) => {
  const user = getAuth().currentUser;
  if (user) {
    const token = await user.getIdToken();
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const upsertUser        = ()         => api.post("/auth/me");
export const sendMessage       = (content, conversation_id = null) =>
  api.post("/ai/chat", { content, conversation_id }).then(r => r.data);
export const listConversations = ()         => api.get("/ai/conversations").then(r => r.data);
export const getConversation   = (id)       => api.get(`/ai/conversations/${id}`).then(r => r.data);
export const listTrips         = ()         => api.get("/trips/").then(r => r.data);
export const createTrip        = (data)     => api.post("/trips/", data).then(r => r.data);
export const updateTrip        = (id, data) => api.put(`/trips/${id}`, data).then(r => r.data);
export const deleteTrip        = (id)       => api.delete(`/trips/${id}`);
