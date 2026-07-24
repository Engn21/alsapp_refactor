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
}) {
  return {
    id: office.id,
    province: office.province,
    name: office.name,
    address: office.address,
    phone: office.phone,
    lat: office.lat,
    lon: office.lon,
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
    const offices = await prisma.ministryOffice.findMany({
      orderBy: { province: "asc" },
    });
    res.json(offices.map(serializeMinistryOffice));
  } catch (err) {
    next(err);
  }
}
