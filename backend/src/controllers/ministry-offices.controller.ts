import { Response, NextFunction } from "express";
import { AuthedRequest } from "../middleware/auth";
import { prisma } from "../lib/prisma";

function serializeMinistryOffice(office: {
  id: string;
  province: string;
  name: string;
  address: string;
  phone: string;
  lat: number;
  lon: number;
  country: string;
}) {
  return {
    id: office.id,
    province: office.province,
    name: office.name,
    address: office.address,
    phone: office.phone,
    lat: office.lat,
    lon: office.lon,
    country: office.country,
  };
}

// Public reference data (no owner-scoping needed) - route still sits
// behind requireAuth for consistency with every other route in the app.
export async function listMinistryOffices(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    // Defaults to Turkey for backward compatibility with clients that
    // don't send this param yet.
    const country = (req.query.country as string) || "TR";
    const offices = await prisma.ministryOffice.findMany({
      where: { country },
      orderBy: { province: "asc" },
    });
    res.json(offices.map(serializeMinistryOffice));
  } catch (err) {
    next(err);
  }
}
