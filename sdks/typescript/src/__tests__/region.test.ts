/**
 * One stack per region; keys are region-bound; the SDK picks the host.
 *
 * Precedence: baseUrl > COMPLYEDGE_API_URL > region / COMPLYEDGE_REGION >
 * key prefix > US. A `ce_eu_` key sent to the US stack is refused with
 * 401 wrong_region on its first call, so the constructor must route it to
 * eu.api.complyedge.io without being told.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("axios", () => ({
  default: {
    create: vi.fn(() => ({ post: vi.fn() })),
  },
}));

import axios from "axios";
import { ComplyEdgeClient, regionFromApiKey, resolveBaseUrl } from "../client";

const US = "https://api.complyedge.io";
const EU = "https://eu.api.complyedge.io";

describe("regionFromApiKey", () => {
  it("reads the region from the prefix, longest prefix first", () => {
    expect(regionFromApiKey("ce_eu_abc")).toBe("eu");
    expect(regionFromApiKey("ce_abc")).toBe("us");
    expect(regionFromApiKey("sk-other")).toBeUndefined();
    expect(regionFromApiKey(undefined)).toBeUndefined();
  });
});

describe("resolveBaseUrl", () => {
  const saved = { url: process.env.COMPLYEDGE_API_URL, region: process.env.COMPLYEDGE_REGION };
  beforeEach(() => {
    delete process.env.COMPLYEDGE_API_URL;
    delete process.env.COMPLYEDGE_REGION;
  });
  afterEach(() => {
    if (saved.url === undefined) delete process.env.COMPLYEDGE_API_URL;
    else process.env.COMPLYEDGE_API_URL = saved.url;
    if (saved.region === undefined) delete process.env.COMPLYEDGE_REGION;
    else process.env.COMPLYEDGE_REGION = saved.region;
  });

  it("the key alone picks the region", () => {
    expect(resolveBaseUrl({ apiKey: "ce_eu_x" })).toBe(EU);
    expect(resolveBaseUrl({ apiKey: "ce_x" })).toBe(US);
    expect(resolveBaseUrl({ apiKey: "unknown" })).toBe(US);
  });

  it("region option beats the key", () => {
    expect(resolveBaseUrl({ apiKey: "ce_eu_x", region: "us" })).toBe(US);
    expect(resolveBaseUrl({ apiKey: "ce_x", region: "eu" })).toBe(EU);
  });

  it("COMPLYEDGE_REGION beats the key but not the option", () => {
    process.env.COMPLYEDGE_REGION = "eu";
    expect(resolveBaseUrl({ apiKey: "ce_x" })).toBe(EU);
    expect(resolveBaseUrl({ apiKey: "ce_x", region: "us" })).toBe(US);
  });

  it("COMPLYEDGE_API_URL beats region", () => {
    process.env.COMPLYEDGE_API_URL = "http://env.local/";
    expect(resolveBaseUrl({ apiKey: "ce_eu_x", region: "us" })).toBe("http://env.local");
  });

  it("baseUrl beats everything", () => {
    process.env.COMPLYEDGE_API_URL = "http://env.local/";
    process.env.COMPLYEDGE_REGION = "eu";
    expect(resolveBaseUrl({ apiKey: "ce_eu_x", baseUrl: "http://localhost:8000/", region: "us" })).toBe(
      "http://localhost:8000"
    );
  });

  it("refuses an unknown region loudly", () => {
    expect(() => resolveBaseUrl({ apiKey: "ce_x", region: "mars" as never })).toThrow(/Unknown ComplyEdge region/);
  });

  it("the constructor routes a ce_eu_ key to the EU stack", () => {
    new ComplyEdgeClient({ apiKey: "ce_eu_k" });
    expect(axios.create).toHaveBeenLastCalledWith(expect.objectContaining({ baseURL: EU }));
    new ComplyEdgeClient({ apiKey: "ce_eu_k", region: "us" });
    expect(axios.create).toHaveBeenLastCalledWith(expect.objectContaining({ baseURL: US }));
  });
});
