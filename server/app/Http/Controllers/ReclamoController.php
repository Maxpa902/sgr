<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReclamoMapaResource;
use App\Models\EstadoReclamo;
use App\Models\Reclamo;
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
    public function store(Request $request): JsonResponse
    {
        $data =$request->validate([
            'tipo_reclamo_id' => ['required', 'integer', Rule::exists('tipos_reclamo', 'id')],
            'descripcion' => ['required', 'string', 'max:1000'],
            'latitud' => ['required', 'numeric'],
            'longitud' => ['required', 'numeric'],
            'es_publico' => ['required', 'boolean'],
            'imagen' => ['required', 'image', 'max:5120'], // Máximo 5MB
        ]);

        $file =$request->file('imagen');

        // 1. Enviar la imagen como multipart/form-data a la API de Sightengine
        $sightengineResponse = Http::attach(
            'media',
            file_get_contents($file->path()),$file->getClientOriginalName()
        )->post('https://api.sightengine.com/1.0/check.json', [
            'models'     => 'nudity-2.0,gore',
            'api_user'   => config('services.sightengine.user'),
            'api_secret' => config('services.sightengine.secret'),
        ]);

       // 2. Analizar la probabilidad devuelta por Sightengine
if ($sightengineResponse->successful()) {
    $result = $sightengineResponse->json();
    $nudity = $result['nudity'] ?? [];
    $classes = $nudity['suggestive_classes'] ?? [];

    $rawNudity      = $nudity['raw'] ?? 0;
    $erotica        = $nudity['erotica'] ?? 0;
    $sexualActivity = $nudity['sexual_activity'] ?? 0;
    $goreProb       = $result['gore']['prob'] ?? 0;

    $suggestive    = $nudity['suggestive'] ?? 0;
    $bikini        = $classes['bikini'] ?? 0;
    $maleChest     = $classes['male_chest'] ?? 0;
    $lingerie      = $classes['lingerie'] ?? 0;
    $maleUnderwear = $classes['male_underwear'] ?? 0;

    // Rechazar si hay desnudez/gore (> 50%) o personas en bikini/sin remera/ropa interior (> 20%)
    if (
        $rawNudity > 0.50 || $erotica > 0.50 || $sexualActivity > 0.50 || $goreProb > 0.50 ||
        $bikini > 0.20 || $maleChest > 0.20 || $lingerie > 0.20 || $maleUnderwear > 0.20 || $suggestive > 0.40
    ) {
        return response()->json([
            'message' => 'La foto fue rechazada automáticamente por contener material inapropiado para un reclamo urbano.'
        ], 422);
    }
}}

}
