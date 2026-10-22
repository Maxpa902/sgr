<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoMapaResource;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use Illuminate\Support\Facades\Http;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\Rule;

class ReclamoController extends Controller
{
    /**
     * Lista los reclamos públicos para el mapa. Sin filtro de estados devuelve solo los activos.
     * Acepta varios estados y categorías: `?estados[]=pendiente&estados[]=resuelto&tipos[]=3`.
     */

  

    public function index(Request $request): AnonymousResourceCollection
    {
        $filtros = $request->validate([
            'estados' => ['sometimes', 'array'],
            'estados.*' => ['string', Rule::exists('estados_reclamo', 'nombre')],
            'tipos' => ['sometimes', 'array'],
            'tipos.*' => ['integer', Rule::exists('tipos_reclamo', 'id')],
        ]);

        $estados = $filtros['estados'] ?? EstadoReclamo::ACTIVOS;

        $reclamos = Reclamo::query()
            ->publicos()
            ->whereHas('estado', fn (Builder $query) => $query->whereIn('nombre', $estados))
            ->when(
                isset($filtros['tipos']),
                fn (Builder $query) => $query->whereIn('tipo_reclamo_id', $filtros['tipos']),
            )
            ->with(['tipoReclamo', 'estado'])
            ->withCount([
                'votos as confirmaciones_count' => fn (Builder $query) => $query->where('valor', 'confirma'),
                'votos as desmentidas_count' => fn (Builder $query) => $query->where('valor', 'desmiente'),
            ])
            ->latest()
            ->get();

        return ReclamoMapaResource::collection($reclamos);
    }

    /**
     * Busca reclamos públicos activos cercanos del mismo tipo para verificar si ya existe.
     * Calcula la distancia en metros utilizando la fórmula de Haversine en SQL.
     */
    public function checkDuplicates(Request $request): JsonResponse
    {
        $data =$request->validate([
            'latitud' => ['required', 'numeric'],
            'longitud' => ['required', 'numeric'],
            'tipo_reclamo_id' => ['required', 'integer', Rule::exists('tipos_reclamo', 'id')],
            'radio_metros' => ['sometimes', 'integer', 'min:10', 'max:500'],
        ]);

        $lat =$data['latitud'];
        $lng =$data['longitud'];
        $radio =$data['radio_metros'] ?? 100;

        $duplicados = Reclamo::query()
            ->publicos()
            ->whereHas('estado', fn (Builder $query) =>$query->whereIn('nombre', EstadoReclamo::ACTIVOS))
            ->where('tipo_reclamo_id', $data['tipo_reclamo_id'])
            ->selectRaw("*, ( 6371000 * acos( cos( radians(?) ) * cos( radians( latitud ) ) * cos( radians( longitud ) - radians(?) ) + sin( radians(?) ) * sin( radians( latitud ) ) ) ) AS distancia_metros", [$lat, $lng,$lat])
            ->having("distancia_metros", "<=", $radio)
            ->orderBy("distancia_metros")
            ->with(['tipoReclamo', 'estado'])
            ->get();

        return response()->json([
            'has_duplicates' => $duplicados->isNotEmpty(),
            'reclamos' => ReclamoMapaResource::collection($duplicados),
        ]);
    }

    /**
     * Registra un nuevo reclamo aplicando el filtro de IA con Sightengine para la foto.
     */
    public function store(Request $request)
{
    $validated = $request->validate([
        'titulo' => 'required|string|max:255',
        'descripcion' => 'required|string',
        'tipo_reclamo_id' => 'required|exists:tipos_reclamo,id',
        'latitud' => 'required|numeric',
        'longitud' => 'required|numeric',
        'direccion' => 'nullable|string|max:255',
        'foto' => 'nullable|image|max:10240',
    ]);

    // 1. MODERACIÓN CON IA (Sightengine)
    // Se ejecuta solo si el usuario adjuntó una foto
    if ($request->hasFile('foto')) {
        $file = $request->file('foto');

        $sightengineResponse = Http::attach(
            'media',
            file_get_contents($file->path()),
            $file->getClientOriginalName()
        )->post('https://api.sightengine.com/1.0/check.json', [
            'models'     => 'nudity-2.0,gore,face-attributes',
            'api_user'   => config('services.sightengine.user'),
            'api_secret' => config('services.sightengine.secret'),
        ]);

        if ($sightengineResponse->successful()) {
            $result = $sightengineResponse->json();
            $nudity = $result['nudity'] ?? [];
            $classes = $nudity['suggestive_classes'] ?? [];
            $faces   = $result['faces'] ?? [];

            $rawNudity      = $nudity['raw'] ?? 0;
            $erotica        = $nudity['erotica'] ?? 0;
            $sexualActivity = $nudity['sexual_activity'] ?? 0;
            $goreProb       = $result['gore']['prob'] ?? 0;

            $suggestive    = $nudity['suggestive'] ?? 0;
            $bikini        = $classes['bikini'] ?? 0;
            $maleChest     = $classes['male_chest'] ?? 0;
            $lingerie      = $classes['lingerie'] ?? 0;
            $maleUnderwear = $classes['male_underwear'] ?? 0;

            // Frena la petición si hay rostros/personas, gore o vestimenta/contenido inapropiado
            if (
                count($faces) > 0 ||
                $rawNudity > 0.50 || $erotica > 0.50 || $sexualActivity > 0.50 || $goreProb > 0.50 ||
                $bikini > 0.20 || $maleChest > 0.20 || $lingerie > 0.20 || $maleUnderwear > 0.20 || $suggestive > 0.40
            ) {
                return response()->json([
                    'message' => 'La foto fue rechazada automáticamente. Las imágenes no deben contener personas ni contenido inapropiado.'
                ], 422);
            }
        }
    }

    // 2. GEOCODIFICACIÓN INVERSA (Código de tu compañera)
    $direccion = $validated['direccion'] ?? null;

    if (! $direccion) {
        try {
            $response = Http::withHeaders([
                'User-Agent' => 'SGR-App/1.0',
            ])->get('https://nominatim.openstreetmap.org/reverse', [
                'format' => 'json',
                'lat' => $validated['latitud'],
                'lon' => $validated['longitud'],
                'zoom' => 18,
            ]);

            if ($response->successful()) {
                $address = $response->json('address');
                $barrio = $address['suburb'] ?? $address['neighbourhood'] ?? $address['city_district'] ?? '';
                $calle = $address['road'] ?? '';
                $direccion = trim("$barrio $calle");
            }
        } catch (\Throwable $e) {
            // Ignorar error de API externa
        }
    }

    // 3. CREACIÓN DEL RECLAMO (Código de tu compañera)
    $reclamo = $request->user()->reclamos()->create([
        'titulo' => $validated['titulo'],
        'descripcion' => $validated['descripcion'],
        'tipo_reclamo_id' => $validated['tipo_reclamo_id'],
        'latitud' => $validated['latitud'],
        'longitud' => $validated['longitud'],
        'direccion' => $direccion,
        'estado_id' => 1,
    ]);

    // 4. GUARDADO DE LA FOTO EN DISCO Y BASE DE DATOS (Código de tu compañera)
    if ($request->hasFile('foto')) {
        $path = $request->file('foto')->store('reclamos', 'public');
        $reclamo->fotos()->create(['ruta' => $path]);
    }

    // 5. RESPUESTA Y RECURSO (Código de tu compañera)
    $reclamo->load(['tipoReclamo', 'estado']);
    $reclamo->confirmaciones_count = 0;
    $reclamo->desmentidas_count = 0;

    return (new ReclamoMapaResource($reclamo))
        ->response()
        ->setStatusCode(201);
}}