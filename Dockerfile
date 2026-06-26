# syntax=docker/dockerfile:1

###############################################
# Stage 1 — Build (TypeScript + client Prisma)
###############################################
FROM node:20-alpine AS builder

# Prisma a besoin d'openssl pour générer/exécuter ses moteurs
RUN apk add --no-cache openssl

WORKDIR /app

# Installation des dépendances (avec devDependencies pour tsc & prisma)
COPY package.json package-lock.json ./
RUN npm ci

# Génération du client Prisma à partir du schéma
COPY prisma ./prisma
RUN npx prisma generate

# Compilation TypeScript -> dist/
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

###############################################
# Stage 2 — Runtime (image finale légère)
###############################################
FROM node:20-alpine AS runner

RUN apk add --no-cache openssl

ENV NODE_ENV=production
ENV PORT=3001

WORKDIR /app

# Dépendances de production uniquement
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Schéma + client Prisma généré (récupéré depuis le builder)
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Code compilé
COPY --from=builder /app/dist ./dist

# Exécution avec l'utilisateur non-root fourni par l'image node
USER node

EXPOSE 3001

CMD ["node", "dist/server.js"]
